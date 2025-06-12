import Foundation
import Combine
import SwiftUI
import WidgetKit

class FitKingViewModel: ObservableObject {
    private let groupID = "group.com.sloaninnovation.FitKing"
    private var sharedDefaults: UserDefaults?
    
    @Published var settings: TrackingSettings {
        didSet {
            settings.save()
            scheduleProgressCheck()
        }
    }
    @Published var currentFitnessData: DailyFitnessData = DailyFitnessData() {
        didSet {
            WidgetCenter.shared.reloadAllTimelines()
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
        
        // Listen for fitness data updates from observers
        NotificationCenter.default.addObserver(
            forName: .init("FitKingFitnessUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let fitnessData = notification.userInfo?["fitnessData"] as? DailyFitnessData {
                self?.currentFitnessData = fitnessData
            }
        }
    }
    
    func startTracking() {
        DispatchQueue.main.async {
            print("Starting fitness tracking")
            self.isTracking = true
            // Observers will handle updates automatically
        }
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
            NotificationManager.shared.scheduleFitnessProgressNotification(
                fitnessData: currentFitnessData,
                settings: settings,
                date: nextCheck
            )
        }
    }
    
    private func checkProgress() {
        let now = Date()
        guard now.timeIntervalSince(lastProgressCheck) >= (settings.notificationFrequency * 30) else {
            print("Skipping progress check - too soon since last check")
            return
        }
        
        print("Checking fitness progress...")
        
        // Use current fitness data from observers
        self.analyzeProgress(data: self.currentFitnessData)
        self.lastProgressCheck = now
    }
    
    private func analyzeProgress(data: DailyFitnessData) {
        print("Analyzing progress with current fitness data: \(data)")
        let now = Date()
        
        // Only send notifications during the user's preferred time window
        guard settings.isWithinTrackingPeriod(now) else {
            print("Outside notification window (\(settings.startTime) to \(settings.todayEndTime)) - skipping notification")
            return
        }
        
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
        
        print("""
            Progress Analysis:
            - Current data: \(data)
            - Settings: \(settings)
            - Remaining hours until \(endDateTime): \(remainingHours)
            """)
        
        // Check if any metrics need attention
        var needsAttention = false
        
        for metricType in FitnessMetricType.allCases {
            let status = data.getProgressStatus(for: metricType, settings: settings)
            if !status.isSuccess && status.percentage < 0.8 {
                needsAttention = true
                break
            }
        }
        
        if needsAttention {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            NotificationManager.shared.scheduleFitnessProgressNotification(
                fitnessData: currentFitnessData,
                settings: settings,
                date: now
            )
        }
    }
    
    private func startLiveUpdates() {
        // Update UI every 30 seconds
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateFitnessData()
        }
    }
    
    private func updateFitnessData() {
        HealthKitManager.shared.getTodayFitnessData { [weak self] data, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error getting fitness data: \(error)")
                    return
                }
                
                self.currentFitnessData = data
                self.checkNotificationNeeded(data: data)
            }
        }
    }
    
    private func checkNotificationNeeded(data: DailyFitnessData) {
        let now = Date()
        let minimumInterval = settings.notificationFrequency * 60 // Convert minutes to seconds
        let timeSinceLastNotification = now.timeIntervalSince(lastNotificationTime)
        
        guard timeSinceLastNotification >= minimumInterval else {
            return // Silently return - no need to log every check
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
        analyzeProgress(data: data)
        lastNotificationTime = now
    }
    
    // Helper methods to get progress for specific metrics
    func getProgressStatus(for type: FitnessMetricType) -> ProgressStatus {
        return currentFitnessData.getProgressStatus(for: type, settings: settings)
    }
    
    func getCurrentValue(for type: FitnessMetricType) -> Double {
        return currentFitnessData.getValue(for: type)
    }
    
    func getTarget(for type: FitnessMetricType) -> Double {
        switch type {
        case .weight:
            return settings.goalWeight
        case .calories:
            return Double(settings.maxDailyCalories)
        case .carbs:
            return Double(settings.maxDailyCarbs)
        case .protein:
            return Double(settings.targetProtein)
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
} 
