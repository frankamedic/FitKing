import Foundation
import HealthKit
import WidgetKit
import UIKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
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
    
    private func updateSharedDefaults(steps: Int) {
        if let defaults = UserDefaults(suiteName: "group.com.sloaninnovation.StepKing") {
            defaults.set(steps, forKey: "lastSteps")
            print("Saved steps to shared defaults: \(steps)")
        }
    }
    
    private func startRegularObserver(for stepType: HKQuantityType) {
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            func signalCompletion(reason: String) {
                print("✅ Signaling ready for next update: \(reason)")
                completionHandler()
            }
            
            guard let self = self else {
                signalCompletion(reason: "self was nil")
                return 
            }
            
            if let error = error {
                print("❌ Observer query error: \(error.localizedDescription)")
                signalCompletion(reason: "error occurred")
                return
            }
            
            var backgroundTaskId = UIBackgroundTaskIdentifier.invalid
            backgroundTaskId = UIApplication.shared.beginBackgroundTask { 
                signalCompletion(reason: "background task expiring")
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            self.getTodaySteps { steps, error in
                DispatchQueue.main.async {
                    let settings = TrackingSettings.load()
                    
                    print("""
                        📊 Step Observer Update:
                        - Current steps: \(steps)
                        - Goal: \(settings.dailyStepGoal)
                        - Within tracking period: \(settings.isWithinTrackingPeriod())
                        """)
                    
                    if settings.isWithinTrackingPeriod() {
                        NotificationManager.shared.scheduleStepProgressNotification(
                            currentSteps: steps,
                            goalSteps: settings.dailyStepGoal,
                            endTime: settings.todayEndTime,
                            date: Date(),
                            source: .healthKitObserver
                        )
                    }
                    
                    // Update shared defaults with latest steps
                    self.updateSharedDefaults(steps: steps)
                    self.updateSteps(steps)
                    
                    if backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskId)
                    }
                    signalCompletion(reason: "step update processed")
                }
            }
        }
        
        healthStore.execute(query)
        observerQuery = query
    }
    
    private func startAnchoredObserver(for stepType: HKQuantityType) {
        // Create predicate for today only
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
} 
