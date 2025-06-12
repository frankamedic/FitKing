import Foundation
import HealthKit
import WidgetKit
import UIKit

// HealthKitManager handles all HealthKit interactions:
// - Requesting authorization to read fitness data
// - Getting current fitness metrics
// - Observing fitness data changes in real-time
// - Managing background delivery of health data
// - Updating shared fitness data for widgets
class HealthKitManager {
    // Single shared instance used throughout the app
    static let shared = HealthKitManager()
    
    // HealthKit's central data store
    // Used to query and observe fitness data
    private let healthStore = HKHealthStore()
    
    // Active queries that watch for fitness data changes
    // Kept as properties to prevent deallocation
    private var observerQueries: [HKObserverQuery] = []
    private var anchoredQueries: [HKAnchoredObjectQuery] = []
    
    // HealthKit quantity types for fitness data
    private var fitnessTypes: [HKQuantityType] {
        let types = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein)
        ]
        return types.compactMap { $0 }
    }
    
    // Requests authorization to access fitness data
    // Must be called before accessing any HealthKit data
    // Enables background delivery for real-time updates
    // Parameters:
    // - completion: Called with success/error after user responds
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("Requesting HealthKit authorization for fitness data...")
        
        let typesToRead: Set<HKSampleType> = Set(fitnessTypes)
        
        // Enable background delivery for all fitness types
        let group = DispatchGroup()
        var hasError = false
        
        for type in fitnessTypes {
            group.enter()
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error = error {
                    print("❌ Failed to enable background delivery for \(type): \(error.localizedDescription)")
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                print("HealthKit authorization response - Success: \(success), Error: \(String(describing: error))")
                completion(success && !hasError, error)
            }
        }
    }
    
    // Gets today's fitness data for all metrics
    // Parameters:
    // - completion: Called with fitness data or error
    func getTodayFitnessData(completion: @escaping (DailyFitnessData, Error?) -> Void) {
        print("Getting today's fitness data...")
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        var fitnessData = DailyFitnessData(date: now)
        
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Get weight data
        group.enter()
        getLatestWeight { weight, error in
            if let error = error {
                errors.append(error)
            } else {
                fitnessData.weight = weight
            }
            group.leave()
        }
        
        // Get calories data
        group.enter()
        getTodayCalories { calories, error in
            if let error = error {
                errors.append(error)
            } else {
                fitnessData.calories = calories
            }
            group.leave()
        }
        
        // Get carbs data
        group.enter()
        getTodayCarbs { carbs, error in
            if let error = error {
                errors.append(error)
            } else {
                fitnessData.carbs = carbs
            }
            group.leave()
        }
        
        // Get protein data
        group.enter()
        getTodayProtein { protein, error in
            if let error = error {
                errors.append(error)
            } else {
                fitnessData.protein = protein
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            let combinedError = errors.first
            completion(fitnessData, combinedError)
        }
    }
    
    // Gets the latest weight measurement in user's preferred unit
    private func getLatestWeight(completion: @escaping (Double, Error?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(0, nil)
            return
        }
        
        let settings = TrackingSettings.load()
        let unit = settings.weightUnit == .kilograms ? HKUnit.gramUnit(with: .kilo) : HKUnit.pound()
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { query, samples, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(0, nil)
                return
            }
            
            let weight = sample.quantity.doubleValue(for: unit)
            completion(weight, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Gets today's total calories consumed
    private func getTodayCalories(completion: @escaping (Double, Error?) -> Void) {
        getDailyNutritionTotal(for: .dietaryEnergyConsumed, unit: .kilocalorie(), completion: completion)
    }
    
    // Gets today's total carbs consumed
    private func getTodayCarbs(completion: @escaping (Double, Error?) -> Void) {
        getDailyNutritionTotal(for: .dietaryCarbohydrates, unit: .gram(), completion: completion)
    }
    
    // Gets today's total protein consumed
    private func getTodayProtein(completion: @escaping (Double, Error?) -> Void) {
        getDailyNutritionTotal(for: .dietaryProtein, unit: .gram(), completion: completion)
    }
    
    // Helper method to get daily nutrition totals
    private func getDailyNutritionTotal(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double, Error?) -> Void) {
        guard let nutritionType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0, nil)
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: nutritionType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { query, statistics, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            let total = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(total, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Gets weekly fitness data for a specific metric
    func getWeeklyFitnessData(for type: FitnessMetricType, weeks: Int = 8, settings: TrackingSettings, completion: @escaping ([WeeklyFitnessData], Error?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        var weeklyData: [WeeklyFitnessData] = []
        
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for weekOffset in 0..<weeks {
            group.enter()
            
            // Calculate week start and end dates
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfDay(for: now)),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
                group.leave()
                continue
            }
            
            getWeeklyAverage(for: type, startDate: weekInterval.start, endDate: weekInterval.end) { average, daysWithData, error in
                if let error = error {
                    errors.append(error)
                    group.leave()
                } else {
                    let target = self.getTarget(for: type, settings: settings)
                    
                    // Get previous week average for weight comparison
                    if type == .weight && weekOffset < weeks - 1 {
                        if let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weekOffset + 1), to: calendar.startOfDay(for: now)),
                           let prevWeekInterval = calendar.dateInterval(of: .weekOfYear, for: prevWeekStart) {
                            
                            // Enter the group again for the previous week fetch
                            group.enter()
                            self.getWeeklyAverage(for: type, startDate: prevWeekInterval.start, endDate: prevWeekInterval.end) { prevAverage, _, _ in
                                let previousWeekAverage = prevAverage > 0 ? prevAverage : nil
                                
                                let weekData = WeeklyFitnessData(
                                    weekStartDate: weekInterval.start,
                                    weekEndDate: weekInterval.end,
                                    type: type,
                                    dailyAverage: average,
                                    daysWithData: daysWithData,
                                    target: target,
                                    previousWeekAverage: previousWeekAverage
                                )
                                weeklyData.append(weekData)
                                group.leave()
                            }
                        } else {
                            let weekData = WeeklyFitnessData(
                                weekStartDate: weekInterval.start,
                                weekEndDate: weekInterval.end,
                                type: type,
                                dailyAverage: average,
                                daysWithData: daysWithData,
                                target: target,
                                previousWeekAverage: nil
                            )
                            weeklyData.append(weekData)
                        }
                    } else {
                        let weekData = WeeklyFitnessData(
                            weekStartDate: weekInterval.start,
                            weekEndDate: weekInterval.end,
                            type: type,
                            dailyAverage: average,
                            daysWithData: daysWithData,
                            target: target,
                            previousWeekAverage: nil
                        )
                        weeklyData.append(weekData)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let sortedData = weeklyData.sorted { $0.weekStartDate > $1.weekStartDate }
            completion(sortedData, errors.first)
        }
    }
    
    // Gets weekly average for a specific metric
    private func getWeeklyAverage(for type: FitnessMetricType, startDate: Date, endDate: Date, completion: @escaping (Double, Int, Error?) -> Void) {
        switch type {
        case .weight:
            getWeeklyWeightAverage(startDate: startDate, endDate: endDate, completion: completion)
        case .calories:
            getWeeklyNutritionAverage(for: .dietaryEnergyConsumed, unit: .kilocalorie(), startDate: startDate, endDate: endDate, completion: completion)
        case .carbs:
            getWeeklyNutritionAverage(for: .dietaryCarbohydrates, unit: .gram(), startDate: startDate, endDate: endDate, completion: completion)
        case .protein:
            getWeeklyNutritionAverage(for: .dietaryProtein, unit: .gram(), startDate: startDate, endDate: endDate, completion: completion)
        }
    }
    
    // Gets weekly weight average in user's preferred unit
    private func getWeeklyWeightAverage(startDate: Date, endDate: Date, completion: @escaping (Double, Int, Error?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(0, 0, nil)
            return
        }
        
        let settings = TrackingSettings.load()
        let unit = settings.weightUnit == .kilograms ? HKUnit.gramUnit(with: .kilo) : HKUnit.pound()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { query, samples, error in
            if let error = error {
                completion(0, 0, error)
                return
            }
            
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                completion(0, 0, nil)
                return
            }
            
            let totalWeight = samples.reduce(0) { total, sample in
                total + sample.quantity.doubleValue(for: unit)
            }
            
            let average = totalWeight / Double(samples.count)
            let daysWithData = Set(samples.map { Calendar.current.startOfDay(for: $0.startDate) }).count
            
            completion(average, daysWithData, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Gets weekly nutrition average
    private func getWeeklyNutritionAverage(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, startDate: Date, endDate: Date, completion: @escaping (Double, Int, Error?) -> Void) {
        guard let nutritionType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0, 0, nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: nutritionType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            if let error = error {
                completion(0, 0, error)
                return
            }
            
            guard let results = results else {
                completion(0, 0, nil)
                return
            }
            
            var totalValue: Double = 0
            var daysWithData = 0
            
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                if let quantity = statistics.sumQuantity() {
                    let value = quantity.doubleValue(for: unit)
                    if value > 0 {
                        totalValue += value
                        daysWithData += 1
                    }
                }
            }
            
            let average = daysWithData > 0 ? totalValue / Double(daysWithData) : 0
            completion(average, daysWithData, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Gets target value for a specific metric type
    private func getTarget(for type: FitnessMetricType, settings: TrackingSettings) -> Double {
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
    
    // Starts observing fitness data changes by:
    // - Setting up real-time observer queries
    // - Creating anchored queries for historical changes
    // - Enabling background delivery of updates
    // Parameters:
    // - completion: Called when observers are set up
    func startFitnessObserver(completion: @escaping () -> Void) {
        print("🏃‍♂️ Starting fitness observer...")
        
        for type in fitnessTypes {
            startRegularObserver(for: type)
            startAnchoredObserver(for: type)
        }
        
        completion()
    }
    
    // Updates the fitness data in shared UserDefaults
    // Used by the widget to display current data
    // Parameters:
    // - data: Current fitness data to save
    private func updateSharedDefaults(data: DailyFitnessData) {
        if let defaults = UserDefaults(suiteName: "group.com.sloaninnovation.FitKing") {
            if let encoded = try? JSONEncoder().encode(data) {
                defaults.set(encoded, forKey: "lastFitnessData")
                print("Saved fitness data to shared defaults")
            }
        }
    }
    
    // Sets up real-time fitness data observer that:
    // - Triggers immediately when new data is recorded
    // - Manages background task lifecycle
    // - Updates shared fitness data
    // - Schedules notifications if needed
    private func startRegularObserver(for type: HKQuantityType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] query, completionHandler, error in
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
            
            // Set up a timeout for getTodayFitnessData to prevent hanging
            let workItem = DispatchWorkItem {
                print("⏱️ getTodayFitnessData timed out")
                completionHandler()
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
            
            // Query current fitness data and handle the response
            self.getTodayFitnessData { data, error in
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
                                📊 Fitness Observer Update (Delayed):
                                - Current data: \(data)
                                - Within tracking period: \(settings.isWithinTrackingPeriod())
                                - Initial state: \(appState.rawValue)
                                - Final state: \(finalState.rawValue)
                                """)
                            
                            // Schedule notification only if:
                            // - Within user's tracking period
                            // - App has fully transitioned to background
                            if settings.isWithinTrackingPeriod() && finalState == .background {
                                NotificationManager.shared.scheduleFitnessProgressNotification(
                                    fitnessData: data,
                                    settings: settings,
                                    date: Date(),
                                    source: .healthKitObserver
                                )
                            }
                            // Update fitness data in shared storage and notify observers
                            self.updateFitnessData(data)
                        }
                    } else {
                        // Handle immediate updates when app state isn't changing
                        // Log current state for debugging
                        print("""
                            📊 Fitness Observer Update:
                            - Current data: \(data)
                            - Within tracking period: \(settings.isWithinTrackingPeriod())
                            - App state: \(appState.rawValue)
                            """)
                        
                        // Schedule notification if within tracking period and in background
                        if settings.isWithinTrackingPeriod() && appState == .background {
                            NotificationManager.shared.scheduleFitnessProgressNotification(
                                fitnessData: data,
                                settings: settings,
                                date: Date(),
                                source: .healthKitObserver
                            )
                        }
                        
                        // Update fitness data in shared storage and notify observers
                        self.updateFitnessData(data)
                    }
                    
                    // Complete the task
                    completionHandler()
                    if backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskId)
                    }
                }
            }
        }
        
        observerQueries.append(query)
        healthStore.execute(query)
    }
    
    // Sets up anchored observer for tracking changes since last update
    private func startAnchoredObserver(for type: HKQuantityType) {
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("❌ Anchored query error: \(error.localizedDescription)")
                return
            }
            
            if let samples = samples, !samples.isEmpty {
                print("📈 Received \(samples.count) new fitness samples")
                
                // Trigger fitness data update
                self?.getTodayFitnessData { data, error in
                    DispatchQueue.main.async {
                        self?.updateFitnessData(data)
                    }
                }
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("❌ Anchored query update error: \(error.localizedDescription)")
                return
            }
            
            if let samples = samples, !samples.isEmpty {
                print("📈 Anchored update: \(samples.count) new fitness samples")
                
                // Trigger fitness data update
                self?.getTodayFitnessData { data, error in
                    DispatchQueue.main.async {
                        self?.updateFitnessData(data)
                    }
                }
            }
        }
        
        anchoredQueries.append(query)
        healthStore.execute(query)
    }
    
    // Updates fitness data and notifies observers
    private func updateFitnessData(_ data: DailyFitnessData) {
        updateSharedDefaults(data: data)
        
        // Notify the app about fitness data updates
        NotificationCenter.default.post(
            name: .init("FitKingFitnessUpdated"),
            object: nil,
            userInfo: ["fitnessData": data]
        )
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // Gets daily data for this week for a specific metric
    func getThisWeekDailyData(for metric: FitnessMetricType, settings: TrackingSettings, completion: @escaping ([DailyMetricData], Error?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the current week's date interval
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            completion([], nil)
            return
        }
        
        var dailyData: [DailyMetricData] = []
        let dispatchGroup = DispatchGroup()
        
        // Generate all 7 days of the week
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) else {
                continue
            }
            
            dispatchGroup.enter()
            getDailyValue(for: metric, date: day, settings: settings) { value, error in
                // Calculate target inline to avoid method signature confusion
                let target: Double
                switch metric {
                case .weight:
                    target = settings.goalWeight
                case .calories:
                    target = Double(settings.maxDailyCalories)
                case .carbs:
                    target = Double(settings.maxDailyCarbs)
                case .protein:
                    target = Double(settings.targetProtein)
                }
                
                let dayData = DailyMetricData(
                    date: day,
                    value: value,
                    target: target,
                    metric: metric
                )
                dailyData.append(dayData)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let sortedData = dailyData.sorted { $0.date < $1.date }
            completion(sortedData, nil)
        }
    }
    
    // Gets daily value for a specific metric and date
    private func getDailyValue(for metric: FitnessMetricType, date: Date, settings: TrackingSettings, completion: @escaping (Double, Error?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        switch metric {
        case .weight:
            getWeeklyWeightAverage(startDate: startOfDay, endDate: endOfDay) { weight, count, error in
                completion(weight, error)
            }
        case .calories:
            getDailyNutrition(for: .dietaryEnergyConsumed, unit: .kilocalorie(), from: startOfDay, to: endOfDay) { value, error in
                completion(value, error)
            }
        case .carbs:
            getDailyNutrition(for: .dietaryCarbohydrates, unit: .gram(), from: startOfDay, to: endOfDay) { value, error in
                completion(value, error)
            }
        case .protein:
            getDailyNutrition(for: .dietaryProtein, unit: .gram(), from: startOfDay, to: endOfDay) { value, error in
                completion(value, error)
            }
        }
    }
    
    // Gets daily nutrition value for a specific identifier and date range
    private func getDailyNutrition(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date, completion: @escaping (Double, Error?) -> Void) {
        guard let nutritionType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0, nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: nutritionType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { query, result, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(value, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Gets average weight loss per week over the last 4 weeks
    // Returns positive number for weight loss, negative for weight gain
    func getAverageWeightLossPerWeek(completion: @escaping (Double, Error?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let settings = TrackingSettings.load()
        
        // Get 5 weeks of data to ensure we have previous week data for calculations
        getWeeklyFitnessData(for: .weight, weeks: 5, settings: settings) { weeklyData, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            guard weeklyData.count >= 2 else {
                completion(0, nil) // Not enough data
                return
            }
            
            // Sort by date (oldest first)
            let sortedData = weeklyData.sorted { $0.weekStartDate < $1.weekStartDate }
            
            // Calculate total weight change from first to last week
            let firstWeek = sortedData.first!
            let lastWeek = sortedData.last!
            let totalWeightChange = firstWeek.dailyAverage - lastWeek.dailyAverage // Positive = weight loss
            
            // Calculate number of weeks between first and last
            let weeksBetween = calendar.dateComponents([.weekOfYear], 
                                                     from: firstWeek.weekStartDate, 
                                                     to: lastWeek.weekStartDate).weekOfYear ?? 1
            
            let averageWeightLossPerWeek = weeksBetween > 0 ? totalWeightChange / Double(weeksBetween) : 0
            
            completion(averageWeightLossPerWeek, nil)
        }
    }
} 
