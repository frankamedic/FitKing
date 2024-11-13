import UserNotifications
import BackgroundTasks

class NotificationManager {
    static let shared = NotificationManager()
    private var lastNotificationTime: Date = Date.distantPast
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification authorization granted: \(granted)")
                } else {
                    print("Notification authorization denied. Error: \(String(describing: error))")
                }
            }
        }
    }
    
    func createStepProgressNotification(currentSteps: Int, goalSteps: Int, endTime: Date) -> (title: String, body: String)? {
        let stepsNeeded = goalSteps - currentSteps
        guard stepsNeeded > 0 else { return nil }
        
        let hoursRemaining = Date().distance(to: endTime) / 3600
        guard hoursRemaining > 0 else { return nil }
        
        let stepsPerHour = Int(ceil(Double(stepsNeeded) / hoursRemaining))
        
        // Format end time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let formattedEndTime = formatter.string(from: endTime)
        
        return (
            title: "Step Progress Update",
            body: "You need to walk about \(stepsPerHour) steps per hour to reach your goal of \(goalSteps) steps by \(formattedEndTime)."
        )
    }
    
    func scheduleStepProgressNotification(
        currentSteps: Int,
        goalSteps: Int,
        endTime: Date,
        date: Date,
        isTest: Bool = false
    ) {
        if !isTest {
            let settings = TrackingSettings.load()
            let minimumInterval = settings.notificationFrequency * 60 // Full interval in seconds
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotificationTime)
            let nextAllowedNotification = lastNotificationTime.addingTimeInterval(minimumInterval)
            
            print("""
                ⏰ Notification Request:
                - Current time: \(Date())
                - User's interval: \(settings.notificationFrequency) minutes
                - Time since last: \(Int(timeSinceLastNotification)) seconds
                - Minimum required: \(Int(minimumInterval)) seconds
                - Last notification: \(lastNotificationTime)
                - Next allowed: \(nextAllowedNotification)
                """)
            
            guard timeSinceLastNotification >= minimumInterval else {
                print("⚠️ Skipping notification - too soon (need \(Int(minimumInterval - timeSinceLastNotification)) more seconds)")
                return
            }
        }
        
        guard let (title, body) = createStepProgressNotification(
            currentSteps: currentSteps,
            goalSteps: goalSteps,
            endTime: endTime
        ) else { return }
        
        scheduleNotification(title: title, body: body, date: date)
        
        if !isTest {
            lastNotificationTime = Date()
            print("✅ Notification scheduled - updated last notification time to: \(lastNotificationTime)")
        }
    }
    
    func scheduleNotification(title: String, body: String, date: Date) {
        // First check if we have permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings status: \(settings.authorizationStatus.rawValue)")
            
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
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sloaninnovation.StepKing.refresh",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("📱 Background refresh started at: \(Date())")
        
        // Schedule next refresh first
        scheduleBackgroundRefresh()
        
        let settings = TrackingSettings.load()
        print("📋 Current notification settings: \(settings.notificationFrequency) minutes")
        
        // Get latest steps and check progress
        HealthKitManager.shared.getTodaySteps { steps, error in
            if let error = error {
                print("❌ Error getting steps in background: \(error)")
                task.setTaskCompleted(success: false)
                return
            }
            
            print("""
                📊 Background Check:
                - Current steps: \(steps)
                - Goal: \(settings.dailyStepGoal)
                - Time: \(Date())
                """)
            
            // Calculate if notification is needed
            let stepsNeeded = settings.dailyStepGoal - steps
            let hoursRemaining = Date().distance(to: settings.todayEndTime) / 3600
            
            if hoursRemaining > 0 && stepsNeeded > 0 {
                let requiredPace = Int(ceil(Double(stepsNeeded) / hoursRemaining))
                self.scheduleStepProgressNotification(
                    currentSteps: steps,
                    goalSteps: settings.dailyStepGoal,
                    endTime: settings.todayEndTime,
                    date: Date()
                )
            }
            
            task.setTaskCompleted(success: true)
        }
    }
    
    func scheduleBackgroundRefresh() {
        let settings = TrackingSettings.load()
        
        // Check if enough time has passed since last notification
        let timeSinceLastNotification = Date().timeIntervalSince(lastNotificationTime)
        let minimumInterval = settings.notificationFrequency * 60 // in seconds
        
        guard timeSinceLastNotification >= minimumInterval else {
            let nextAllowedTime = lastNotificationTime.addingTimeInterval(minimumInterval)
            print("""
                🔄 Skipping background refresh schedule:
                - Current time: \(Date())
                - Last notification: \(lastNotificationTime)
                - Next allowed: \(nextAllowedTime)
                - Need to wait: \(Int(minimumInterval - timeSinceLastNotification)) seconds
                """)
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: "com.sloaninnovation.StepKing.refresh")
        let intervalInSeconds = settings.notificationFrequency * 60
        let nextRefreshDate = Date(timeIntervalSinceNow: intervalInSeconds)
        request.earliestBeginDate = nextRefreshDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("""
                🔄 Background Refresh Scheduled:
                - Current time: \(Date())
                - Notification frequency: \(settings.notificationFrequency) minutes
                - Next refresh scheduled: \(nextRefreshDate)
                - Interval: \(intervalInSeconds) seconds
                """)
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
} 