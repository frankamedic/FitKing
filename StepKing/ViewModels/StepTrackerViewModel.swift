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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sharedDefaults?.setValue(self.currentSteps, forKey: "currentSteps")
                self.sharedDefaults?.synchronize()
                print("Saved steps to shared defaults: \(self.currentSteps)")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    @Published var isTracking: Bool = false
    @Published var error: String? = nil
    
    private var timer: Timer?
    private var updateTimer: Timer?
    
    init() {
        self.settings = TrackingSettings.load()
        self.sharedDefaults = UserDefaults(suiteName: groupID)
    }
    
    func startTracking() {
        print("Starting step tracking")
        isTracking = true
        checkProgress() // Immediate check
        scheduleProgressCheck()
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
        print("Checking step progress...")
        HealthKitManager.shared.getTodaySteps { [weak self] steps, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error getting steps: \(error)")
                    self.error = error.localizedDescription
                    return
                }
                
                print("Received step count: \(steps)")
                self.currentSteps = steps
                self.analyzeProgress()
            }
        }
    }
    
    private func analyzeProgress() {
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
        // Update every 10 seconds when app is active
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            print("Performing live update check")
            self?.checkProgress()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
} 
