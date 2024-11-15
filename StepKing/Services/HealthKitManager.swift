import Foundation
import HealthKit
import WidgetKit
import UIKit

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
        print("🏃‍♂️ Starting step observer...")
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        // Create observer query
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Observer query error: \(error.localizedDescription)")
                completion()
                return
            }
            
            // Request background time
            let backgroundTask = UIApplication.shared.beginBackgroundTask {
                completion()
            }
            
            // Handle step update
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
                    
                    // End background task
                    if backgroundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTask)
                    }
                    completion()
                }
            }
        }
        
        // Execute query and enable background delivery
        healthStore.execute(query)
        observerQuery = query
        
        // Enable background delivery
        setupBackgroundDelivery()
    }
    
    func stopStepObserver() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
    
    func setupBackgroundDelivery() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        // Request background updates with immediate frequency
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("❌ Failed to enable background delivery: \(error.localizedDescription)")
                return
            }
            print("✅ Successfully enabled background delivery for steps")
            
            // Force an initial background delivery
            self.getTodaySteps { steps, error in
                if let error = error {
                    print("❌ Initial steps check failed: \(error.localizedDescription)")
                    return
                }
                print("✅ Initial background delivery completed with \(steps) steps")
            }
        }
    }
} 