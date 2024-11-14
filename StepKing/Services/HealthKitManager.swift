import Foundation
import HealthKit
import WidgetKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("Requesting HealthKit authorization...")
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            print("HealthKit authorization response - Success: \(success), Error: \(String(describing: error))")
            completion(success, error)
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
    
    func startStepObserver() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { 
            print("Failed to create step count type")
            return 
        }
        
        // Stop any existing query
        stopStepObserver()
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Observer query error: \(error)")
                completion()
                return
            }
            
            self.getTodaySteps { steps, error in
                // Dispatch UI updates to main thread
                DispatchQueue.main.async {
                    // Save to shared UserDefaults for widget
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.sloaninnovation.StepKing") {
                        sharedDefaults.set(steps, forKey: "currentSteps")
                        
                        // Only try to update widget if WidgetKit is available
                        #if canImport(WidgetKit)
                        if #available(iOS 14.0, *) {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        #endif
                    }
                    
                    // Check if notification needed
                    let settings = TrackingSettings.load()
                    if settings.isWithinTrackingPeriod() {
                        NotificationManager.shared.scheduleStepProgressNotification(
                            currentSteps: steps,
                            goalSteps: settings.dailyStepGoal,
                            endTime: settings.todayEndTime,
                            date: Date()
                        )
                    }
                }
                
                completion()
            }
        }
        
        observerQuery = query
        healthStore.execute(query)
        
        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to enable background delivery: \(error)")
                } else {
                    print("Successfully enabled background delivery for steps")
                }
            }
        }
    }
    
    func stopStepObserver() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
} 