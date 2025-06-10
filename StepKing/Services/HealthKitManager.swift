import Foundation
import HealthKit
import WidgetKit
import UIKit

// HealthKitManager handles all HealthKit interactions:
// - Requesting authorization to read step data
// - Getting current step counts
// - Observing step count changes in real-time
// - Managing background delivery of health data
// - Updating shared step data for widgets
class HealthKitManager {
    // Single shared instance used throughout the app
    static let shared = HealthKitManager()
    
    // HealthKit's central data store
    // Used to query and observe step counts
    private let healthStore = HKHealthStore()
    
    // Active queries that watch for step count changes
    // Kept as properties to prevent deallocation
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    // Requests authorization to access step count data
    // Must be called before accessing any HealthKit data
    // Enables background delivery for real-time updates
    // Parameters:
    // - completion: Called with success/error after user responds
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("Requesting HealthKit authorization...")
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            completion(false, nil)
            return
        }
        
        // Add background delivery authorization
        let typesToRead: Set<HKSampleType> = [stepType]
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("❌ Failed to enable background delivery during authorization: \(error.localizedDescription)")
            }
            
            self.healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                print("HealthKit authorization response - Success: \(success), Error: \(String(describing: error))")
                completion(success, error)
            }
        }
    }
    
    // Gets the total step count for today by:
    // - Creating a query from midnight to now
    // - Requesting the cumulative sum of steps
    // - Handling any HealthKit errors
    // Parameters:
    // - completion: Called with step count or error
    func getTodaySteps(completion: @escaping (Int, Error?) -> Void) {
        print("Getting today's steps...")
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            completion(0, nil)
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        print("Querying steps from \(startOfDay) to \(now)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            if let error = error {
                print("HealthKit Query Error: \(error.localizedDescription)")
                completion(0, error)
                return
            }
            
            guard let results = results else {
                print("No results returned from HealthKit")
                completion(0, nil)
                return
            }
            
            results.enumerateStatistics(from: startOfDay, to: now) { statistics, stop in
                if let quantity = statistics.sumQuantity() {
                    let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                    print("Steps retrieved from HealthKit: \(steps)")
                    completion(steps, nil)
                } else {
                    print("No steps quantity available for period")
                    completion(0, nil)
                }
            }
        }
        
        print("Executing HealthKit query...")
        healthStore.execute(query)
    }
    
    // Starts observing step count changes by:
    // - Setting up a real-time observer query
    // - Creating an anchored query for historical changes
    // - Enabling background delivery of updates
    // Parameters:
    // - completion: Called when observers are set up
    func startStepObserver(completion: @escaping () -> Void) {
        print("🏃‍♂️ Starting step observer...")
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            completion()
            return
        }
        
        startRegularObserver(for: stepType)
        startAnchoredObserver(for: stepType)
        
        completion()
    }
    
    // Updates the step count in shared UserDefaults
    // Used by the widget to display current steps
    // Parameters:
    // - steps: Current step count to save
    private func updateSharedDefaults(steps: Int) {
        if let defaults = UserDefaults(suiteName: "group.com.sloaninnovation.StepKing") {
            defaults.set(steps, forKey: "lastSteps")
            print("Saved steps to shared defaults: \(steps)")
        }
    }
    
    // Sets up real-time step count observer that:
    // - Triggers immediately when new steps are recorded
    // - Manages background task lifecycle
    // - Updates shared step count
    // - Schedules notifications if needed
    private func startRegularObserver(for stepType: HKQuantityType) {
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
            
            // Create background task with timeout
            backgroundTaskId = UIApplication.shared.beginBackgroundTask { 
                print("⚠️ Background task expiring")
                completionHandler()
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            // Set a 10-second timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if backgroundTaskId != .invalid {
                    print("⏱️ Enforcing 10-second timeout (ending open background tasks)")
                    completionHandler()
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            guard let self = self else {
                completionHandler()
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
                return
            }
            
            if let error = error {
                print("❌ Observer query error: \(error.localizedDescription)")
                completionHandler()
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
                return
            }
            
            // Set up a timeout for getTodaySteps to prevent hanging
            let workItem = DispatchWorkItem {
                print("⏱️ getTodaySteps timed out")
                completionHandler()
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
            
            // Query current step count and handle the response
            self.getTodaySteps { steps, error in
                // Cancel the timeout since we got a response
                workItem.cancel()
                
                DispatchQueue.main.async {
                    let settings = TrackingSettings.load()
                    let appState = UIApplication.shared.applicationState
                    
                    // Special handling for when app is transitioning to background
                    // This prevents missing updates during state changes
                    if appState == .inactive {
                        // Wait 0.5 seconds for app to complete transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let finalState = UIApplication.shared.applicationState
                            // Log detailed state information for debugging
                            print("""
                                📊 Step Observer Update (Delayed):
                                - Current steps: \(steps)
                                - Goal: \(settings.dailyStepGoal)
                                - Within tracking period: \(settings.isWithinTrackingPeriod())
                                - Initial state: \(appState.rawValue)
                                - Final state: \(finalState.rawValue)
                                """)
                            
                            // Schedule notification only if:
                            // - Within user's tracking period
                            // - App has fully transitioned to background
                            if settings.isWithinTrackingPeriod() && finalState == .background {
                                NotificationManager.shared.scheduleStepProgressNotification(
                                    currentSteps: steps,
                                    goalSteps: settings.dailyStepGoal,
                                    endTime: settings.todayEndTime,
                                    date: Date(),
                                    source: .healthKitObserver
                                )
                            }
                            // Update step count in shared storage and notify observers
                            self.updateSteps(steps)
                        }
                    } else {
                        // Handle immediate updates when app state isn't changing
                        // Log current state for debugging
                        print("""
                            📊 Step Observer Update:
                            - Current steps: \(steps)
                            - Goal: \(settings.dailyStepGoal)
                            - Within tracking period: \(settings.isWithinTrackingPeriod())
                            - App state: \(appState.rawValue)
                            """)
                        
                        // Schedule notification only if:
                        // - Within user's tracking period
                        // - App is already in background
                        if settings.isWithinTrackingPeriod() && appState == .background {
                            NotificationManager.shared.scheduleStepProgressNotification(
                                currentSteps: steps,
                                goalSteps: settings.dailyStepGoal,
                                endTime: settings.todayEndTime,
                                date: Date(),
                                source: .healthKitObserver
                            )
                        } else {
                            print("📱 Skipping notification - app not in background")
                        }
                        
                        // Update step count in both shared defaults and through notification
                        self.updateSharedDefaults(steps: steps)
                        self.updateSteps(steps)
                    }
                    
                    // Clean up background task
                    completionHandler()
                    if backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskId)
                    }
                }
            }
        }
        
        // Start the observer query and retain it
        healthStore.execute(query)
        observerQuery = query
    }
    
    // Sets up an anchored query that:
    // - Tracks historical step count changes
    // - Handles device-locked scenarios
    // - Updates shared step count
    // - Manages its own background task lifecycle
    private func startAnchoredObserver(for stepType: HKQuantityType) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let anchoredQuery = HKAnchoredObjectQuery(
            type: stepType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, _, _, _, error in
            guard let self = self else { return }
            
            var backgroundTaskId = UIBackgroundTaskIdentifier.invalid
            backgroundTaskId = UIApplication.shared.beginBackgroundTask { 
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            func endBackgroundTask(reason: String) {
                print("📍 Ending anchored query background task: \(reason)")
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            if let error = error {
                print("📍 Anchored query error: \(error.localizedDescription)")
                if error.localizedDescription.contains("Protected health data is inaccessible") {
                    print("📍 Protected data error - using last known steps")
                    // Use shared defaults when device is locked
                    if let defaults = UserDefaults(suiteName: "group.com.sloaninnovation.StepKing"),
                       let lastKnownSteps = defaults.object(forKey: "lastSteps") as? Int {
                        print("📍 Last known steps from defaults: \(lastKnownSteps)")
                        DispatchQueue.main.async {
                            self.updateSteps(lastKnownSteps)
                            endBackgroundTask(reason: "used last known steps")
                        }
                        return
                    }
                }
                endBackgroundTask(reason: "error occurred")
                return
            }
            
            print("📍 Anchored query received update - querying total steps...")
            self.getTodaySteps { steps, error in
                if let error = error {
                    print("📍 Could not get total steps: \(error.localizedDescription)")
                    endBackgroundTask(reason: "getTodaySteps error")
                    return
                }
                DispatchQueue.main.async {
                    self.updateSteps(steps)
                    endBackgroundTask(reason: "steps updated")
                }
            }
        }
        
        anchoredQuery.updateHandler = { query, samples, deletedObjects, newAnchor, error in
            print("📍 Anchored query update handler called")
            if let error = error {
                print("📍 Anchored query update error: \(error.localizedDescription)")
                return
            }
            
            if let samples = samples {
                print("📍 Anchored query received \(samples.count) updates in update handler")
            }
        }
        
        healthStore.execute(anchoredQuery)
        self.anchoredQuery = anchoredQuery
        print("📍 Anchored query started")
    }
    
    // Stops all step count observers:
    // - Cancels the real-time observer query
    // - Stops the anchored query
    // - Disables background delivery
    func stopStepObserver() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        
        if let query = anchoredQuery {
            healthStore.stop(query)
            anchoredQuery = nil
            print("📍 Anchored query stopped")
        }
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        healthStore.disableBackgroundDelivery(for: stepType) { success, error in
            if let error = error {
                print("❌ Failed to disable background delivery: \(error.localizedDescription)")
                return
            }
            print("✅ Background delivery disabled")
        }
    }
    
    // Enables background delivery of step count updates
    // Called when app needs real-time step data in background
    func enableBackgroundDelivery(completion: @escaping () -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion()
            return
        }
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("❌ Failed to enable background delivery: \(error.localizedDescription)")
                completion()
                return
            }
            print("✅ Background delivery enabled for background mode")
            completion()
        }
    }
    
    // Disables background delivery of step count updates
    // Called when app doesn't need real-time updates
    func disableBackgroundDelivery(completion: @escaping () -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion()
            return
        }
        
        healthStore.disableBackgroundDelivery(for: stepType) { success, error in
            if let error = error {
                print("❌ Failed to disable background delivery: \(error.localizedDescription)")
                completion()
                return
            }
            print("✅ Background delivery disabled for active mode")
            completion()
        }
    }
    
    // Updates step count and notifies observers by:
    // - Saving to shared UserDefaults for widget
    // - Posting notification for UI updates
    // Parameters:
    // - steps: Current step count to broadcast
    private func updateSteps(_ steps: Int) {
        DispatchQueue.main.async {
            self.updateSharedDefaults(steps: steps)
            NotificationCenter.default.post(
                name: .init("StepKingStepsUpdated"),
                object: nil,
                userInfo: ["steps": steps]
            )
        }
    }
    
    // Gets weekly step data for the past 12 weeks
    // Returns an array of WeeklyStepData with daily averages
    // Parameters:
    // - goalSteps: Daily step goal to calculate progress against
    // - completion: Called with array of weekly data or error
    func getWeeklyStepData(goalSteps: Int, completion: @escaping ([WeeklyStepData], Error?) -> Void) {
        print("Getting weekly step data for past 12 weeks...")
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            completion([], nil)
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate the start of the current week (Sunday)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        // Go back 12 weeks from current week start
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: currentWeekStart) else {
            completion([], nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            if let error = error {
                print("HealthKit Weekly Query Error: \(error.localizedDescription)")
                completion([], error)
                return
            }
            
            guard let results = results else {
                print("No weekly results returned from HealthKit")
                completion([], nil)
                return
            }
            
            var weeklyData: [WeeklyStepData] = []
            
            // Process data week by week
            for weekOffset in 0..<12 {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate) else {
                    continue
                }
                
                guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
                    continue
                }
                
                // Don't go beyond current date
                let actualWeekEnd = min(weekEnd, now)
                
                var totalSteps = 0
                var daysWithData = 0
                
                // Sum up steps for each day in the week
                results.enumerateStatistics(from: weekStart, to: actualWeekEnd) { statistics, stop in
                    if let quantity = statistics.sumQuantity() {
                        let daySteps = Int(quantity.doubleValue(for: HKUnit.count()))
                        if daySteps > 0 {
                            totalSteps += daySteps
                            daysWithData += 1
                        }
                    }
                }
                
                // Calculate daily average (only count days with data to avoid dilution)
                let dailyAverage = daysWithData > 0 ? totalSteps / daysWithData : 0
                
                let weekData = WeeklyStepData(
                    weekStartDate: weekStart,
                    weekEndDate: actualWeekEnd,
                    totalSteps: totalSteps,
                    dailyAverage: dailyAverage,
                    daysWithData: daysWithData,
                    goalSteps: goalSteps
                )
                
                weeklyData.append(weekData)
            }
            
            // Sort by week start date (most recent first)
            weeklyData.sort { $0.weekStartDate > $1.weekStartDate }
            
            print("Retrieved \(weeklyData.count) weeks of step data")
            completion(weeklyData, nil)
        }
        
        print("Executing weekly HealthKit query...")
        healthStore.execute(query)
    }
} 
