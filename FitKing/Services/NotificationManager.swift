import UserNotifications
import BackgroundTasks
import UIKit

// NotificationManager handles all notification-related tasks:
// - Scheduling notifications about step progress
// - Managing background refresh tasks to check steps
// - Controlling notification timing and frequency
// - Working with HealthKit to get step data
class NotificationManager {
    // Single shared instance used throughout the app
    static let shared = NotificationManager()
    
    // Matches the background task identifier in Info.plist
    // Used by iOS to identify our background refresh requests
    static let backgroundTaskIdentifier = "com.sloaninnovation.FitKing.refresh"
    
    // Tracks when we last showed a notification
    // Used to prevent showing notifications too frequently
    public private(set) var lastNotificationTime: Date = Date.distantPast
    
    // iOS requires at least 15 minutes between background refreshes
    // This ensures we don't request refreshes more often than allowed
    private let minimumBackgroundInterval: TimeInterval = 15 * 60 // 15 minutes
    
    // Calculates when we should show the next notification by checking:
    // - Are we in the user's tracking period? (e.g., 9am-5pm)
    // - How long since last notification?
    // - What's the user's preferred notification frequency?
    // Returns nil if we shouldn't show a notification
    var nextNotificationTime: Date? {
        let settings = TrackingSettings.load()
        
        // If we're outside tracking period, return nil
        guard settings.isWithinTrackingPeriod() else {
            return nil
        }
        
        // Calculate next notification time based on frequency
        let minimumInterval = settings.notificationFrequency * 60
        let nextTime = lastNotificationTime.addingTimeInterval(minimumInterval)
        
        // If next time would be after end time, return nil
        if nextTime > settings.todayEndTime {
            return nil
        }
        
        return nextTime
    }
    
    // Asks user for permission to send notifications
    // Requests authorization for alerts, badges, and sounds
    // Logs whether permission was granted and checks existing notifications
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification authorization granted: \(granted)")
                    self.checkPendingNotifications()
                } else {
                    print("Notification authorization denied. Error: \(String(describing: error))")
                }
            }
        }
    }
    
    // Creates the content for a step progress notification by:
    // - Calculating how many steps are still needed
    // - Determining how much time is left today
    // - Computing the required pace (steps per hour)
    // - Checking if user is behind expected progress
    // Returns: Title and body text for notification, or nil if no notification needed
    func createStepProgressNotification(currentSteps: Int, goalSteps: Int, endTime: Date) -> (title: String, body: String)? {
        print("📝 Creating step progress notification...")
        let stepsNeeded = goalSteps - currentSteps
        print("- Steps needed: \(stepsNeeded)")
        
        guard stepsNeeded > 0 else {
            print("⚠️ No notification needed - already reached goal")
            return nil
        }
        
        let hoursRemaining = Date().distance(to: endTime) / 3600
        print("- Hours remaining: \(hoursRemaining)")
        
        guard hoursRemaining > 0 else {
            print("⚠️ No notification needed - past end time")
            return nil
        }
        
        let stepsPerHour = Int(ceil(Double(stepsNeeded) / hoursRemaining))
        print("- Required pace: \(stepsPerHour) steps/hour")
        
        // Calculate expected progress based on time of day
        let settings = TrackingSettings.load()
        let expectedProgress = settings.expectedProgress()
        let expectedSteps = Int(Double(goalSteps) * expectedProgress)
        print("""
            Progress Check:
            - Expected progress: \(expectedProgress * 100)%
            - Expected steps: \(expectedSteps)
            - Current steps: \(currentSteps)
            """)
        
        let percentComplete = (Double(currentSteps) / Double(goalSteps) * 100).rounded(to: 1)
        let expectedPercent = (expectedProgress * 100).rounded(to: 1)
        let percentBehind = (expectedPercent - percentComplete).rounded(to: 1)
        
        // Only create notification if meaningfully behind expected pace (1% or more)
        guard currentSteps < expectedSteps && percentBehind >= 1.0 else {
            print("⚠️ No notification needed - ahead of pace or less than 1% behind")
            return nil
        }
        
        // Format end time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let formattedEndTime = formatter.string(from: endTime)
        
        // Add more context to the notification
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        let formattedCurrentSteps = numberFormatter.string(from: NSNumber(value: currentSteps)) ?? "\(currentSteps)"
        let formattedGoalSteps = numberFormatter.string(from: NSNumber(value: goalSteps)) ?? "\(goalSteps)"
        let formattedPaceSteps = numberFormatter.string(from: NSNumber(value: stepsPerHour)) ?? "\(stepsPerHour)"
        
        print("✅ Creating notification content")
        return (
            title: String(format: "You're %.1f%% behind - Let's catch up! 💪", percentBehind),
            body: String(format: """
                At %.1f%% (%@ of %@ steps)
                Need %@ steps/hr to reach goal by %@
                """, percentComplete, formattedCurrentSteps, formattedGoalSteps, formattedPaceSteps, formattedEndTime)
        )
    }
    
    // Defines where a notification request came from:
    // - healthKitObserver: When HealthKit detects new steps
    // - backgroundRefresh: When iOS wakes up our app periodically
    enum NotificationSource {
        case healthKitObserver
        case backgroundRefresh
    }
    
    // A dedicated queue for processing notifications
    // Ensures only one notification is being scheduled at a time
    // Prevents conflicts when multiple parts of the app request notifications
    private let notificationQueue = DispatchQueue(label: "com.sloaninnovation.FitKing.notificationQueue")
    
    // Tracks if we're currently in the process of scheduling a notification
    // Helps prevent duplicate notifications from being scheduled
    private var isSchedulingNotification = false
    
    // Attempts to schedule a step progress notification if:
    // - Enough time has passed since last notification
    // - User is behind their expected pace
    // - App is in background state
    // - We're within the user's tracking period
    // Parameters:
    // - currentSteps: User's current step count
    // - goalSteps: User's daily step goal
    // - endTime: When today's tracking period ends
    // - date: When to show the notification
    // - source: What triggered this notification request
    func scheduleStepProgressNotification(
        currentSteps: Int,
        goalSteps: Int,
        endTime: Date,
        date: Date,
        source: NotificationSource = .backgroundRefresh
    ) {
        // Process notification request on dedicated queue
        notificationQueue.async { [weak self] in
            guard let self = self,
                  !self.isSchedulingNotification else {
                print("⏳ Already scheduling a notification, skipping...")
                return
            }
            
            self.isSchedulingNotification = true
            defer { self.isSchedulingNotification = false }
            
            // Validate input parameters
            guard currentSteps >= 0, 
                  goalSteps > 0, 
                  date.timeIntervalSinceNow > -1 else {
                print("❌ Invalid parameters for notification scheduling:")
                print("- Current steps: \(currentSteps)")
                print("- Goal steps: \(goalSteps)") 
                print("- Schedule date: \(date)")
                return
            }
            
            let settings = TrackingSettings.load()
            let notificationInterval = settings.notificationFrequency * 60
            let timeSinceLastNotification = Date().timeIntervalSince(self.lastNotificationTime)
            
            guard timeSinceLastNotification >= notificationInterval else {
                print("⏳ Too soon since last notification (\(Int(timeSinceLastNotification))s / \(notificationInterval)s)")
                return
            }
            
            // Try to create notification content
            guard let (title, body) = self.createStepProgressNotification(
                currentSteps: currentSteps,
                goalSteps: goalSteps,
                endTime: endTime
            ) else {
                print("❌ No notification content created - conditions not met")
                return
            }
            
            // Schedule notification and refresh background tasks
            DispatchQueue.main.sync {
                self.scheduleNotification(title: title, body: body, date: date)
                self.rescheduleBackgroundRefresh()
            }
        }
    }
    
    // Creates the content for a fitness progress notification by:
    // - Checking which metrics need attention
    // - Determining time left in tracking period
    // - Creating motivational messaging
    // Returns: Title and body text for notification, or nil if no notification needed
    func createFitnessProgressNotification(fitnessData: DailyFitnessData, settings: TrackingSettings, endTime: Date) -> (title: String, body: String)? {
        print("📝 Creating fitness progress notification...")
        
        let hoursRemaining = Date().distance(to: endTime) / 3600
        print("- Hours remaining: \(hoursRemaining)")
        
        guard hoursRemaining > 0 else {
            print("⚠️ No notification needed - past end time")
            return nil
        }
        
        // Check which metrics need attention
        var needsAttention: [FitnessMetricType] = []
        
        for metricType in FitnessMetricType.allCases {
            let status = fitnessData.getProgressStatus(for: metricType, settings: settings)
            if !status.isSuccess && status.percentage < 0.8 {
                needsAttention.append(metricType)
            }
        }
        
        guard !needsAttention.isEmpty else {
            print("⚠️ No notification needed - all metrics on track")
            return nil
        }
        
        print("📊 Metrics needing attention: \(needsAttention.map { $0.rawValue })")
        
        // Format end time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let formattedEndTime = formatter.string(from: endTime)
        
        let title: String
        let body: String
        
        if needsAttention.count == 1 {
            let metric = needsAttention[0]
            let status = fitnessData.getProgressStatus(for: metric, settings: settings)
            
            switch metric {
            case .weight:
                title = "Weight Goal Check-in 💪"
                body = "Track your weight to stay on target"
            case .calories:
                let remaining = Int(status.target - status.current)
                title = "Calorie Limit Alert 🔥"
                body = "You have \(remaining) calories left until \(formattedEndTime)"
            case .carbs:
                let remaining = Int(status.target - status.current)
                title = "Carb Limit Alert 🍞"
                body = "You have \(remaining)g carbs left until \(formattedEndTime)"
            case .protein:
                let needed = Int(status.target - status.current)
                title = "Protein Goal Reminder 🥩"
                body = "You need \(needed)g more protein by \(formattedEndTime)"
            }
        } else {
            title = "Fitness Goals Check-in 🎯"
            let metricNames = needsAttention.prefix(2).map { $0.rawValue }.joined(separator: " & ")
            body = "\(metricNames) need attention. \(Int(hoursRemaining))h left to reach your goals!"
        }
        
        print("✅ Creating notification content")
        return (title: title, body: body)
    }
    
    // Attempts to schedule a fitness progress notification if:
    // - Enough time has passed since last notification
    // - User has metrics that need attention
    // - App is in background state
    // - We're within the user's tracking period
    // Parameters:
    // - fitnessData: Current day's fitness data
    // - settings: User's fitness goals and preferences
    // - date: When to show the notification
    // - source: What triggered this notification request
    func scheduleFitnessProgressNotification(
        fitnessData: DailyFitnessData,
        settings: TrackingSettings,
        date: Date,
        source: NotificationSource = .backgroundRefresh
    ) {
        // Process notification request on dedicated queue
        notificationQueue.async { [weak self] in
            guard let self = self,
                  !self.isSchedulingNotification else {
                print("⏳ Already scheduling a notification, skipping...")
                return
            }
            
            self.isSchedulingNotification = true
            defer { self.isSchedulingNotification = false }
            
            // Validate input parameters
            guard date.timeIntervalSinceNow > -1 else {
                print("❌ Invalid parameters for notification scheduling:")
                print("- Schedule date: \(date)")
                return
            }
            
            let notificationInterval = settings.notificationFrequency * 60
            let timeSinceLastNotification = Date().timeIntervalSince(self.lastNotificationTime)
            
            guard timeSinceLastNotification >= notificationInterval else {
                print("⏳ Too soon since last notification (\(Int(timeSinceLastNotification))s / \(notificationInterval)s)")
                return
            }
            
            // Try to create notification content
            guard let (title, body) = self.createFitnessProgressNotification(
                fitnessData: fitnessData,
                settings: settings,
                endTime: settings.todayEndTime
            ) else {
                print("❌ No notification content created - conditions not met")
                return
            }
            
            // Schedule notification and refresh background tasks
            DispatchQueue.main.sync {
                self.scheduleNotification(title: title, body: body, date: date)
                self.rescheduleBackgroundRefresh()
            }
        }
    }
    
    // After scheduling a notification, ensures background refresh tasks are up to date:
    // 1. Cancels any existing background tasks
    // 2. Schedules a new background refresh task
    private func rescheduleBackgroundRefresh() {
        cleanupBackgroundTasks {
            self.scheduleBackgroundRefresh()
        }
    }
    
    // Creates and schedules a local notification with the provided content
    // Handles:
    // - Foreground state checking
    // - Content validation
    // - Removal of existing notifications
    // - Notification scheduling
    // - Error handling and logging
    func scheduleNotification(title: String, body: String, date: Date) {
        // Add foreground check
        guard UIApplication.shared.applicationState != .active else {
            print("📱 Skipping notification while app is in foreground")
            return
        }
        
        // Add validation
        guard !title.isEmpty, !body.isEmpty else {
            print("❌ Empty notification content")
            return
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Remove existing notifications synchronously using a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Create and schedule the new notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let timeInterval = max(date.timeIntervalSinceNow, 5.0)
        print("📅 Scheduling new notification with time interval: \(timeInterval) seconds")
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        print("📬 Scheduling notification: \(content.title) - \(content.body)")
        
        // Schedule synchronously using a semaphore
        var schedulingError: Error?
        notificationCenter.add(request) { error in
            schedulingError = error
            semaphore.signal()
        }
        semaphore.wait()
        
        if let error = schedulingError {
            print("❌ Error scheduling notification: \(error.localizedDescription)")
            if let error = error as? UNError {
                print("Notification Error Code: \(error.code.rawValue)")
            }
        } else {
            print("✅ Notification scheduled successfully for: \(date)")
            self.lastNotificationTime = Date()
            print("⏱️ Updated last notification time to: \(self.lastNotificationTime)")
            
            // Verify notification was scheduled
            notificationCenter.getPendingNotificationRequests { requests in
                print("📋 Verified pending notifications: \(requests.count)")
                requests.forEach { request in
                    print("- \(request.content.title): scheduled for \(request.trigger?.description ?? "unknown")")
                }
            }
        }
    }
    
    // Registers the app for background refresh capability by:
    // - Setting up the background task handler
    // - Configuring refresh intervals
    // - Scheduling initial background refresh
    // - Logging registration status
    func registerBackgroundTasks() {
        print("""
            🔄 Registering background tasks:
            - Task identifier: \(Self.backgroundTaskIdentifier)
            - BGTaskScheduler available: \(UIApplication.shared.backgroundRefreshStatus == .available)
            - Background modes: \(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") ?? [])
            """)
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: .main
        ) { task in
            print("🎯 Background task handler called")
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        print("✅ Background task registration successful")
        
        scheduleBackgroundRefresh()
    }
    
    // Handles background refresh tasks when iOS wakes up our app:
    // - Updates step counts from HealthKit or shared defaults
    // - Schedules notifications if needed
    // - Manages task completion status
    // - Sets up timeouts to prevent system termination
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("""
            🔄 Background Refresh Started:
            - Task identifier: \(task.identifier)
            - Start time: \(Date())
            - Last notification: \(lastNotificationTime)
            - Time since last: \(Int(Date().timeIntervalSince(lastNotificationTime)) / 60) minutes
            """)
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("⚠️ Background task expired before completion")
            task.setTaskCompleted(success: false)
        }
        
        // Create a timeout to ensure we complete within system limits
        let timeoutWorkItem = DispatchWorkItem {
            print("⚠️ Background task timed out")
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutWorkItem)
        
        let settings = TrackingSettings.load()
        print("""
            📋 Current Settings:
            - Notification frequency: \(settings.notificationFrequency) minutes
            - Weight goal: \(settings.goalWeight) kg
            - Max calories: \(settings.maxDailyCalories) cal
            - Max carbs: \(settings.maxDailyCarbs) g
            - Target protein: \(settings.targetProtein) g
            - Start time: \(settings.startTime)
            - End time: \(settings.endTime)
            - Current time in window: \(settings.isWithinTrackingPeriod())
            """)
        
        // Schedule next refresh before any potential failures
        print("📅 Scheduling next background refresh")
        scheduleBackgroundRefresh()
        
        guard settings.isWithinTrackingPeriod() else {
            print("⏰ Outside tracking period - skipping background check")
            timeoutWorkItem.cancel()
            task.setTaskCompleted(success: true)
            return
        }
        
        // Try to get fitness data from shared defaults first (faster than HealthKit)
        if let defaults = UserDefaults(suiteName: "group.com.sloaninnovation.FitKing"),
           let data = defaults.data(forKey: "lastFitnessData"),
           let lastKnownFitnessData = try? JSONDecoder().decode(DailyFitnessData.self, from: data) {
            print("📊 Using last known fitness data from defaults: \(lastKnownFitnessData)")
            self.scheduleFitnessProgressNotification(
                fitnessData: lastKnownFitnessData,
                settings: settings,
                date: Date()
            )
            task.setTaskCompleted(success: true)
            return
        }
        
        // Fall back to HealthKit if needed
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                print("🏃‍♂️ Requesting current fitness data...")
                HealthKitManager.shared.getTodayFitnessData { [weak self] fitnessData, error in
                    timeoutWorkItem.cancel()
                    
                    guard let self = self else {
                        print("❌ Self was deallocated")
                        task.setTaskCompleted(success: false)
                        return
                    }
                    
                    if let error = error {
                        print("❌ HealthKit error: \(error.localizedDescription)")
                        task.setTaskCompleted(success: false)
                        return
                    }
                    
                    print("""
                        📊 Fitness Progress:
                        - Weight: \(String(format: "%.1f", fitnessData.weight)) kg (target: \(String(format: "%.1f", settings.goalWeight)) kg)
                        - Calories: \(Int(fitnessData.calories)) cal (max: \(settings.maxDailyCalories) cal)
                        - Carbs: \(Int(fitnessData.carbs)) g (max: \(settings.maxDailyCarbs) g)
                        - Protein: \(Int(fitnessData.protein)) g (target: \(settings.targetProtein) g)
                        """)
                    
                    print("🔔 Attempting to schedule notification...")
                    self.scheduleFitnessProgressNotification(
                        fitnessData: fitnessData,
                        settings: settings,
                        date: Date()
                    )
                    
                    print("✅ Background refresh completed")
                    task.setTaskCompleted(success: true)
                }
            } else {
                print("❌ HealthKit authorization failed in background task: \(String(describing: error))")
                timeoutWorkItem.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // Schedules the next background refresh task:
    // - Uses system-required minimum interval (15 minutes)
    // - Handles scheduling errors
    // - Logs scheduling status
    // - Adjusts timing based on tracking period
    func scheduleBackgroundRefresh() {
        let settings = TrackingSettings.load()
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        
        if !settings.isWithinTrackingPeriod() {
            // Calculate next tracking period start time
            if let nextStart = settings.nextTrackingPeriodStart() {
                print("⏰ Outside tracking period - scheduling for next period start at \(nextStart)")
                request.earliestBeginDate = nextStart
                
                do {
                    try BGTaskScheduler.shared.submit(request)
                    print("✅ Background refresh scheduled for next tracking period")
                } catch {
                    print("❌ Could not schedule background refresh: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Could not determine next tracking period start time")
            }
            return
        }
        
        // Schedule within tracking period
        let userInterval = TimeInterval(settings.notificationFrequency * 60)
        let refreshInterval = max(minimumBackgroundInterval, userInterval)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        
        print("""
            📅 Scheduling background refresh:
            - Time: \(request.earliestBeginDate?.description ?? "unknown")
            - User interval: \(userInterval/60) minutes
            - Background interval: \(refreshInterval/60) minutes
            """)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled")
        } catch {
            print("❌ Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    // Cancels all pending background tasks
    // Used when:
    // - Cleaning up resources
    // - Rescheduling tasks
    // - App state changes
    func cleanupBackgroundTasks(completion: (() -> Void)? = nil) {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            requests.forEach { request in
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
                print("🗑️ Cancelled background task: \(request.identifier)")
            }
            completion?()
        }
    }
    
    // Logs all pending notifications for debugging
    // Shows notification content and scheduling details
    func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("""
                📋 Pending Notifications:
                \(requests.map { "- Title: \"\($0.content.title)\", Body: \"\($0.content.body)\"" }.joined(separator: "\n"))
                """)
        }
    }
    
    // Handles app state changes between:
    // - Active (foreground)
    // - Background
    // - Inactive
    // Updates background tasks and notifications accordingly
    func handleAppStateChange(_ state: UIApplication.State) {
        print("""
            📱 App State Changed:
            - New state: \(state.rawValue)
            - Current time: \(Date())
            - Last notification: \(lastNotificationTime)
            """)
        
        switch state {
        case .background:
            print("📲 App entered background")
            checkForMissedNotification()
            
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                print("""
                    📋 Background Tasks Before Scheduling:
                    Total count: \(requests.count)
                    \(requests.map { "- \($0.identifier) scheduled for \($0.earliestBeginDate ?? Date())" }.joined(separator: "\n"))
                    """)
                
                self.scheduleBackgroundRefresh()
                
                BGTaskScheduler.shared.getPendingTaskRequests { requests in
                    print("""
                        📋 Background Tasks After Scheduling:
                        Total count: \(requests.count)
                        \(requests.map { "- \($0.identifier) scheduled for \($0.earliestBeginDate ?? Date())" }.joined(separator: "\n"))
                        """)
                }
            }
            
        case .active:
            print("📲 App became active")
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                print("""
                    📋 Background Tasks Before Cleanup:
                    Total count: \(requests.count)
                    \(requests.map { "- \($0.identifier) scheduled for \($0.earliestBeginDate ?? Date())" }.joined(separator: "\n"))
                    """)
                
                self.cleanupBackgroundTasks()
            }
            
        default:
            break
        }
    }
    
    // Checks if we need to send a notification when app enters background
    // Prevents missing notifications during app state transitions
    private func checkForMissedNotification() {
        let settings = TrackingSettings.load()
        guard settings.isWithinTrackingPeriod() else {
            print("⏰ Outside tracking period - skipping missed notification check")
            return
        }
        
        let timeSinceLastNotification = Date().timeIntervalSince(lastNotificationTime)
        let minimumInterval = settings.notificationFrequency * 60
        
        if timeSinceLastNotification >= minimumInterval {
            print("📲 Checking for notification after app became inactive...")
            HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ HealthKit error during inactive check: \(error.localizedDescription)")
                    return
                }
                
                self.scheduleStepProgressNotification(
                    currentSteps: steps,
                    goalSteps: settings.dailyStepGoal,
                    endTime: settings.todayEndTime,
                    date: Date(),
                    source: .backgroundRefresh
                )
            }
        }
    }
} 
