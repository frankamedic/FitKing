import Foundation
import Combine
import SwiftUI
import WidgetKit

class StepKingViewModel: ObservableObject {
    private let groupID = "group.com.sloaninnovation.StepKing"
    private var sharedDefaults: UserDefaults?
    
    @Published var settings: TrackingSettings {
        didSet {
            settings.save()
            scheduleProgressCheck()
        }
    }
    @Published var currentSteps: Int = 0 {
        didSet {
            Task {
                await MainActor.run {
                    self.sharedDefaults?.setValue(self.currentSteps, forKey: "currentSteps")
                    self.sharedDefaults?.synchronize()
                    print("Saved steps to shared defaults: \(self.currentSteps)")
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
    @Published var isTracking: Bool = false
    @Published var error: String? = nil
    
    private var timer: Timer?
    private var updateTimer: Timer?
    private var lastProgressCheck: Date = .distantPast
    private var lastNotificationTime: Date = .distantPast
    
    init() {
        self.settings = TrackingSettings.load()
        self.sharedDefaults = UserDefaults(suiteName: groupID)
    }
    
    func startTracking() {
        print("Starting step tracking")
        isTracking = true
        updateSteps() // Initial update
        startLiveUpdates()
    }
    
    func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func scheduleProgressCheck() {
        guard isTracking else { return }
        
        let now = Date()
        let nextCheck = now.addingTimeInterval(settings.notificationFrequency * 60)
        
        // Only schedule if within tracking hours
        if Calendar.current.component(.hour, from: nextCheck) <= 
           Calendar.current.component(.hour, from: settings.todayEndTime) {
            NotificationManager.shared.scheduleStepProgressNotification(
                currentSteps: currentSteps,
                goalSteps: settings.dailyStepGoal,
                endTime: settings.todayEndTime,
                date: nextCheck
            )
        }
    }
    
    private func checkProgress() {
        let now = Date()
        // Only check progress if enough time has passed
        guard now.timeIntervalSince(lastProgressCheck) >= (settings.notificationFrequency * 30) else {
            print("Skipping progress check - too soon since last check")
            return
        }
        
        print("Checking step progress...")
        HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
            guard let self = self else { return }
            if let error = error {
                print("Error getting steps: \(error)")
                return
            }
            
            self.currentSteps = steps
            self.analyzeProgress(steps: steps)
            self.lastProgressCheck = now
        }
    }
    
    private func analyzeProgress(steps: Int) {
        print("Analyzing progress with current steps: \(currentSteps)")
        let now = Date()
        
        // Only send notifications during the user's preferred time window
        guard settings.isWithinTrackingPeriod(now) else {
            print("Outside notification window (\(settings.startTime) to \(settings.todayEndTime)) - skipping notification")
            return
        }
        
        let stepsNeeded = settings.dailyStepGoal - currentSteps
        
        // Calculate remaining hours until end of tracking period
        let calendar = Calendar.current
        var endTimeComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let endTimeHourMin = calendar.dateComponents([.hour, .minute], from: settings.todayEndTime)
        endTimeComponents.hour = endTimeHourMin.hour
        endTimeComponents.minute = endTimeHourMin.minute
        
        guard let endDateTime = calendar.date(from: endTimeComponents) else { return }
        
        let remainingHours = max(
            endDateTime.timeIntervalSince(now) / 3600.0,
            1.0
        )
        
        // Calculate required pace
        let stepsPerHour = Int(round(Double(stepsNeeded) / remainingHours / 10) * 10)
        
        print("""
            Progress Analysis:
            - Current steps: \(currentSteps)
            - Daily goal: \(settings.dailyStepGoal)
            - Steps needed: \(stepsNeeded)
            - Remaining hours until \(endDateTime): \(remainingHours)
            - Required pace: \(stepsPerHour) steps/hour
            """)
        
        // Only notify if the required pace is significant
        if stepsPerHour > 100 {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let formattedEndTime = timeFormatter.string(from: endDateTime)
            
            NotificationManager.shared.scheduleStepProgressNotification(
                currentSteps: currentSteps,
                goalSteps: settings.dailyStepGoal,
                endTime: settings.todayEndTime,
                date: now
            )
        }
    }
    
    private func startLiveUpdates() {
        // Update UI every 10 seconds
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateSteps()
        }
    }
    
    private func updateSteps() {
        HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
            guard let self = self else { return }
            if let error = error {
                print("Error getting steps: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self.currentSteps = steps
                self.checkNotificationNeeded(steps: steps)
            }
        }
    }
    
    private func checkNotificationNeeded(steps: Int) {
        let now = Date()
        let minimumInterval = settings.notificationFrequency * 60 // Convert minutes to seconds
        let timeSinceLastNotification = now.timeIntervalSince(lastNotificationTime)
        
        guard timeSinceLastNotification >= minimumInterval else {
            return // Silently return - no need to log every 10 seconds
        }
        
        // Only log when we're actually considering sending a notification
        print("""
            Checking notification timing:
            - Current time: \(now)
            - Time since last: \(Int(timeSinceLastNotification)) seconds
            - Minimum interval: \(Int(minimumInterval)) seconds
            - Last notification: \(lastNotificationTime)
            """)
        
        // If enough time has passed, analyze progress and maybe send notification
        analyzeProgress(steps: steps)
        lastNotificationTime = now
    }
    
    deinit {
        updateTimer?.invalidate()
    }
} 
