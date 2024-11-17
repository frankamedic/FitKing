import UserNotifications
import BackgroundTasks
import UIKit

// NotificationManager is responsible for:
// 1. Scheduling and managing local notifications about step progress
// 2. Handling background refresh tasks to check step counts
// 3. Managing notification timing and frequency
// 4. Coordinating with HealthKit for step data
class NotificationManager {
    // Singleton instance for global access throughout the app
    static let shared = NotificationManager()
    
    // Unique identifier for background refresh tasks, matching Info.plist configuration
    static let backgroundTaskIdentifier = "com.sloaninnovation.StepKing.refresh"
    
    // Tracks the timestamp of the most recent notification to prevent notification spam
    public private(set) var lastNotificationTime: Date = Date.distantPast
    
    // iOS enforces a minimum interval between background refreshes
    private let minimumBackgroundInterval: TimeInterval = 30 * 60 // 30 minutes
    
    // Calculates when the next notification should be shown based on:
    // - Current tracking period (start/end times)
    // - User's notification frequency settings
    // - Last notification time
    // Returns nil if no notification should be scheduled
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
    
    // Requests authorization for local notifications from the user
    // Configures notification types: alerts, badges, and sounds
    // Logs the authorization status and checks pending notifications
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
    
    // Creates notification content based on current step progress
    // Parameters:
    // - currentSteps: User's current step count
    // - goalSteps: User's daily step goal
    // - endTime: When the tracking period ends today
    // Returns: Tuple of notification title and body, or nil if notification not needed
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
        
        // Only create notification if behind expected pace
        guard currentSteps < expectedSteps else {
            print("⚠️ No notification needed - ahead of pace")
            return nil
        }
        
        // Format end time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let formattedEndTime = formatter.string(from: endTime)
        
        // Add more context to the notification
        let percentComplete = Int((Double(currentSteps) / Double(goalSteps)) * 100)
        let expectedPercent = Int((Double(expectedSteps) / Double(goalSteps)) * 100)
        let percentBehind = max(1, expectedPercent - percentComplete)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        let formattedCurrentSteps = numberFormatter.string(from: NSNumber(value: currentSteps)) ?? "\(currentSteps)"
        let formattedGoalSteps = numberFormatter.string(from: NSNumber(value: goalSteps)) ?? "\(goalSteps)"
        let formattedPaceSteps = numberFormatter.string(from: NSNumber(value: stepsPerHour)) ?? "\(stepsPerHour)"
        
        print("✅ Creating notification content")
        return (
            title: "You're \(percentBehind)% behind - Let's catch up! 💪",
            body: """
                At \(percentComplete)% (\(formattedCurrentSteps) of \(formattedGoalSteps) steps)
                Need \(formattedPaceSteps) steps/hr to reach goal by \(formattedEndTime)
                """
        )
    }
    
    // Defines the source of notification triggers
    // - healthKitObserver: Triggered by HealthKit step count changes
    // - backgroundRefresh: Triggered by system background refresh
    enum NotificationSource {
        case healthKitObserver
        case backgroundRefresh
    }
    
    // Serial queue ensures notifications are processed one at a time
    // Prevents race conditions in notification scheduling
    private let notificationQueue = DispatchQueue(label: "com.sloaninnovation.StepKing.notificationQueue")
    
    // Flag to prevent multiple simultaneous notification scheduling attempts
    private var isSchedulingNotification = false
    
    // Schedules a step progress notification if conditions are met:
    // - Enough time has passed since last notification
    // - User is behind their expected pace
    // - Within tracking period
    // - Valid step counts and goals
    func scheduleStepProgressNotification(
        currentSteps: Int,
        goalSteps: Int,
        endTime: Date,
        date: Date,
        source: NotificationSource = .backgroundRefresh
    ) {
        // Ensure we only schedule one at a time
        notificationQueue.async { [weak self] in
            guard let self = self,
                  !self.isSchedulingNotification else {
                print("⏳ Already scheduling a notification, skipping...")
                return
            }
            
            self.isSchedulingNotification = true
            defer { self.isSchedulingNotification = false }
            
            // Validation checks
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
            
            // Create notification content synchronously
            guard let (title, body) = self.createStepProgressNotification(
                currentSteps: currentSteps,
                goalSteps: goalSteps,
                endTime: endTime
            ) else {
                print("❌ No notification content created - conditions not met")
                return
            }
            
            // Schedule on main queue but maintain our lock
            DispatchQueue.main.sync {
                self.scheduleNotification(title: title, body: body, date: date)
                self.rescheduleBackgroundRefresh()
            }
        }
    }
    
    // Cancels existing background tasks and schedules a new one
    // Called after scheduling notifications to ensure background checks continue
    private func rescheduleBackgroundRefresh() {
        // First cancel any existing background tasks
        cleanupBackgroundTasks {
            // Then schedule new one
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
    
    // Registers the app for background refresh capability
    // Sets up the background task handler
    // Schedules initial background refresh
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
        
        // Schedule initial background refresh
        scheduleBackgroundRefresh()
    }
    
    // Handles background refresh tasks when triggered by the system
    // - Updates step counts
    // - Schedules notifications if needed
    // - Manages task completion status
    // - Handles timeouts and errors
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("""
            🔄 Background Refresh Started:
            - Task identifier: \(task.identifier)
            - Start time: \(Date())
            - Last notification: \(lastNotificationTime)
            - Time since last: \(Int(Date().timeIntervalSince(lastNotificationTime)) / 60) minutes
            """)
        
        // Set expiration handler first
        task.expirationHandler = {
            print("⚠️ Background task expired before completion")
            task.setTaskCompleted(success: false)
        }
        
        // Create a timeout
        let timeoutWorkItem = DispatchWorkItem {
            print("⚠️ Background task timed out")
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutWorkItem) // 25 second timeout
        
        let settings = TrackingSettings.load()
        print("""
            📋 Current Settings:
            - Notification frequency: \(settings.notificationFrequency) minutes
            - Daily goal: \(settings.dailyStepGoal) steps
            - Start time: \(settings.startTime)
            - End time: \(settings.endTime)
            - Current time in window: \(settings.isWithinTrackingPeriod())
            """)
        
        // Schedule next refresh first before any potential failures
        print("📅 Scheduling next background refresh")
        scheduleBackgroundRefresh()
        
        guard settings.isWithinTrackingPeriod() else {
            print("⏰ Outside tracking period - skipping background check")
            timeoutWorkItem.cancel()
            task.setTaskCompleted(success: true)
            return
        }
        
        // Request HealthKit authorization before accessing data
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                print("🏃‍♂️ Requesting current step count...")
                HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
                    // Cancel the timeout since we got a response
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
                        📊 Step Progress:
                        - Current steps: \(steps)
                        - Goal: \(settings.dailyStepGoal)
                        - Progress: \(Int((Double(steps) / Double(settings.dailyStepGoal)) * 100))%
                        - Remaining: \(max(0, settings.dailyStepGoal - steps))
                        """)
                    
                    print("🔔 Attempting to schedule notification...")
                    self.scheduleStepProgressNotification(
                        currentSteps: steps,
                        goalSteps: settings.dailyStepGoal,
                        endTime: settings.todayEndTime,
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
    
    // Schedules the next background refresh task
    // Uses system-required minimum interval
    // Handles scheduling errors and logging
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
        
        // Normal scheduling within tracking period
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
    // Used when cleaning up or rescheduling tasks
    // Optional completion handler for post-cleanup actions
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
    // Shows notification titles and bodies
    func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("""
                📋 Pending Notifications:
                \(requests.map { "- Title: \"\($0.content.title)\", Body: \"\($0.content.body)\"" }.joined(separator: "\n"))
                """)
        }
    }
    
    // Manages app state transitions between:
    // - Active (foreground)
    // - Background
    // - Inactive
    // Handles necessary background task scheduling and cleanup
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
            // Check if we need to send a notification immediately
            checkForMissedNotification()
            
            // Log background task status before scheduling
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                print("""
                    📋 Background Tasks Before Scheduling:
                    Total count: \(requests.count)
                    \(requests.map { "- \($0.identifier) scheduled for \($0.earliestBeginDate ?? Date())" }.joined(separator: "\n"))
                    """)
                
                // Schedule new background task
                self.scheduleBackgroundRefresh()
                
                // Log after scheduling
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
            // Log tasks before cleanup
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
    
    // Checks if a notification should be sent when app enters background
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
    
    // Logs detailed background task and notification status
    // Used for debugging background execution issues
    private func debugBackgroundStatus() {
        print("""
            🔍 Background Status Check:
            - Background refresh available: \(UIApplication.shared.backgroundRefreshStatus == .available)
            - Current app state: \(UIApplication.shared.applicationState.rawValue)
            - Last notification time: \(lastNotificationTime)
            - Background modes: \(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") ?? [])
            """)
        
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            print("""
                📋 Current Background Tasks:
                Total count: \(requests.count)
                \(requests.map { "- \($0.identifier) scheduled for \($0.earliestBeginDate ?? Date())" }.joined(separator: "\n"))
                """)
        }
    }
    
    // DEBUG-only method to simulate background refresh
    // Useful for testing notification logic during development
    #if DEBUG
    func simulateBackgroundRefresh() {
        print("🔬 Simulating background refresh...")
        print("🎯 Background task handler called (simulated)")
        
        // Get settings and check if we're in tracking period
        let settings = TrackingSettings.load()
        print("""
            📋 Current Settings:
            - Notification frequency: \(settings.notificationFrequency) minutes
            - Daily goal: \(settings.dailyStepGoal) steps
            - Start time: \(settings.startTime)
            - End time: \(settings.endTime)
            - Current time in window: \(settings.isWithinTrackingPeriod())
            """)
        
        guard settings.isWithinTrackingPeriod() else {
            print("⏰ Outside tracking period - skipping background check")
            return
        }
        
        print("🏃‍♂️ Requesting current step count...")
        HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
            guard let self = self else {
                print("❌ Self was deallocated")
                return
            }
            
            if let error = error {
                print("❌ HealthKit error: \(error.localizedDescription)")
                return
            }
            
            print("""
                📊 Step Progress:
                - Current steps: \(steps)
                - Goal: \(settings.dailyStepGoal)
                - Progress: \(Int((Double(steps) / Double(settings.dailyStepGoal)) * 100))%
                - Remaining: \(max(0, settings.dailyStepGoal - steps))
                """)
            
            print("🔔 Attempting to schedule notification...")
            self.scheduleStepProgressNotification(
                currentSteps: steps,
                goalSteps: settings.dailyStepGoal,
                endTime: settings.todayEndTime,
                date: Date()
            )
            
            print("✅ Simulated background refresh completed")
        }
    }
    #endif
} 
