import Foundation

// Represents the current day's fitness data
struct DailyFitnessData: Codable {
    var weight: Double
    var calories: Double
    var carbs: Double
    var protein: Double
    var date: Date
    
    init(weight: Double = 0, calories: Double = 0, carbs: Double = 0, protein: Double = 0, date: Date = Date()) {
        self.weight = weight
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.date = date
    }
    
    func getValue(for type: FitnessMetricType) -> Double {
        switch type {
        case .weight:
            return weight
        case .calories:
            return calories
        case .carbs:
            return carbs
        case .protein:
            return protein
        }
    }
    
    mutating func setValue(_ value: Double, for type: FitnessMetricType) {
        switch type {
        case .weight:
            weight = value
        case .calories:
            calories = value
        case .carbs:
            carbs = value
        case .protein:
            protein = value
        }
    }
    
    func getProgressStatus(for type: FitnessMetricType, settings: TrackingSettings) -> ProgressStatus {
        let currentValue = getValue(for: type)
        
        switch type {
        case .weight:
            let distance = abs(currentValue - settings.goalWeight)
            return ProgressStatus(
                current: currentValue,
                target: settings.goalWeight,
                isSuccess: distance <= 1.0, // Within 1kg of goal
                percentage: distance > 0 ? min(2.0, 1.0 / distance) : 1.0
            )
        case .calories:
            let isSuccess = currentValue <= Double(settings.maxDailyCalories)
            let percentage = Double(settings.maxDailyCalories) / max(currentValue, 1.0)
            return ProgressStatus(
                current: currentValue,
                target: Double(settings.maxDailyCalories),
                isSuccess: isSuccess,
                percentage: min(percentage, 1.0)
            )
        case .carbs:
            let isSuccess = currentValue <= Double(settings.maxDailyCarbs)
            let percentage = Double(settings.maxDailyCarbs) / max(currentValue, 1.0)
            return ProgressStatus(
                current: currentValue,
                target: Double(settings.maxDailyCarbs),
                isSuccess: isSuccess,
                percentage: min(percentage, 1.0)
            )
        case .protein:
            let isSuccess = currentValue >= Double(settings.targetProtein)
            let percentage = currentValue / Double(settings.targetProtein)
            return ProgressStatus(
                current: currentValue,
                target: Double(settings.targetProtein),
                isSuccess: isSuccess,
                percentage: min(percentage, 1.0)
            )
        }
    }
}

struct ProgressStatus {
    let current: Double
    let target: Double
    let isSuccess: Bool
    let percentage: Double
    
    var color: String {
        if isSuccess {
            return "green"
        } else if percentage >= 0.8 {
            return "yellow"
        } else if percentage >= 0.6 {
            return "orange"
        } else {
            return "red"
        }
    }
} 