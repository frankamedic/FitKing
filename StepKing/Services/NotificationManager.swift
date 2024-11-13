import UserNotifications
import BackgroundTasks

class NotificationManager {
    static let shared = NotificationManager()
    
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
    
    func scheduleStepProgressNotification(currentSteps: Int, goalSteps: Int, endTime: Date, date: Date) {
        print("Preparing step progress notification...")
        print("Current steps: \(currentSteps)")
        print("Goal steps: \(goalSteps)")
        print("End time: \(endTime)")
        print("Scheduled for: \(date)")
        
        guard let (title, body) = createStepProgressNotification(
            currentSteps: currentSteps,
            goalSteps: goalSteps,
            endTime: endTime
        ) else {
            print("❌ Failed to create notification content")
            return
        }
        
        print("Created notification content:")
        print("Title: \(title)")
        print("Body: \(body)")
        
        scheduleNotification(title: title, body: body, date: date)
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
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Perform your step checking and notification logic here
        // Make sure to call task.setTaskCompleted(success: true) when done
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.sloaninnovation.StepKing.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
} 