import UserNotifications
import BackgroundTasks
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    static let backgroundTaskIdentifier = "com.sloaninnovation.StepKing.refresh"
    public private(set) var lastNotificationTime: Date = Date.distantPast
    
    // Minimum interval iOS allows for background refresh
    private let minimumBackgroundInterval: TimeInterval = 30 * 60 // 30 minutes
    
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
        
        print("✅ Creating notification content")
        return (
            title: "Time to step it up!",
            body: """
                Current: \(currentSteps) steps (\(percentComplete)%)
                Needed: \(stepsNeeded) more steps
                Pace: \(stepsPerHour) steps/hour to reach \(goalSteps) by \(formattedEndTime)
                """
        )
    }
    
    enum NotificationSource {
        case healthKitObserver
        case backgroundRefresh
    }
    
    func scheduleStepProgressNotification(
        currentSteps: Int,
        goalSteps: Int,
        endTime: Date,
        date: Date,
        source: NotificationSource = .backgroundRefresh
    ) {
        print("""
            🎯 Attempting to schedule step progress notification:
            - Source: \(source)
            - Current steps: \(currentSteps)
            - Goal steps: \(goalSteps)
            - End time: \(endTime)
            - Schedule date: \(date)
            """)
        
        // Move all the notification logic to main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let settings = TrackingSettings.load()
            // Always use user's frequency for notification timing
            let notificationInterval = settings.notificationFrequency * 60
            let timeSinceLastNotification = Date().timeIntervalSince(self.lastNotificationTime)
            
            print("""
                ⏱ Notification timing check:
                - Time since last: \(Int(timeSinceLastNotification))s
                - Notification interval: \(notificationInterval)s
                - Source: \(source)
                """)
            
            guard timeSinceLastNotification >= notificationInterval else {
                print("⏳ Too soon since last notification (\(Int(timeSinceLastNotification))s / \(notificationInterval)s)")
                return
            }
            
            print("🔍 Checking if notification content should be created...")
            guard let (title, body) = self.createStepProgressNotification(
                currentSteps: currentSteps,
                goalSteps: goalSteps,
                endTime: endTime
            ) else {
                print("❌ No notification content created - conditions not met")
                return
            }
            
            print("📬 Proceeding to schedule notification with content")
            self.scheduleNotification(title: title, body: body, date: date)
            
            // After successful notification, update timestamp and schedule next check
            self.lastNotificationTime = Date()
            print("⏱️ Updated last notification time to: \(self.lastNotificationTime)")
            
            // Always reschedule background task after sending a notification, regardless of source
            self.rescheduleBackgroundRefresh()
        }
    }
    
    private func rescheduleBackgroundRefresh() {
        // First cancel any existing background tasks
        cleanupBackgroundTasks {
            // Then schedule new one
            self.scheduleBackgroundRefresh()
        }
    }
    
    func scheduleNotification(title: String, body: String, date: Date) {
        // First check if we have permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("""
                🔔 Attempting to schedule notification:
                - Title: "\(title)"
                - Body: "\(body)"
                - Date: \(date)
                - Auth Status: \(settings.authorizationStatus.rawValue)
                """)
            
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            // Calculate time interval and ensure it's valid
            let timeInterval = max(date.timeIntervalSinceNow, 1.0)
            print("Scheduling notification with time interval: \(timeInterval) seconds")
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeInterval,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            print("Attempting to schedule notification with content: \(content.title) - \(content.body)")
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification: \(error.localizedDescription)")
                } else {
                    print("✅ Notification scheduled successfully for: \(date)")
                }
            }
        }
    }
    
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
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        // Always use 30 minute interval for background tasks
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumBackgroundInterval)
        
        print("""
            📅 Scheduling background refresh:
            - Time: \(request.earliestBeginDate?.description ?? "unknown")
            - Interval: \(minimumBackgroundInterval/60) minutes
            """)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled")
        } catch {
            print("❌ Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    // Add this method to clean up tasks when needed
    func cleanupBackgroundTasks(completion: (() -> Void)? = nil) {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            requests.forEach { request in
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
                print("🗑️ Cancelled background task: \(request.identifier)")
            }
            completion?()
        }
    }
    
    func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("""
                📋 Pending Notifications:
                \(requests.map { "- Title: \"\($0.content.title)\", Body: \"\($0.content.body)\"" }.joined(separator: "\n"))
                """)
        }
    }
    
    // Add this method to handle app state changes
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
    
    // New method to check if we need to send a notification when app goes to background
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
    
    // Add this method to NotificationManager class
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
