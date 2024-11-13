import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
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
} 