import Foundation

// Represents a week's worth of fitness data
struct WeeklyFitnessData: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let weekEndDate: Date
    let type: FitnessMetricType
    let dailyAverage: Double
    let daysWithData: Int
    let target: Double
    let previousWeekAverage: Double?
    
    // Computed properties for display
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStartDate)
        let endString = formatter.string(from: weekEndDate)
        
        return "\(startString) - \(endString)"
    }
    
    var progressPercentage: Double {
        switch type {
        case .weight:
            // For weight, success is being closer to goal than previous week
            guard let prevAvg = previousWeekAverage, target > 0 else { return 0 }
            let currentDistance = abs(dailyAverage - target)
            let previousDistance = abs(prevAvg - target)
            return previousDistance > 0 ? min(previousDistance / currentDistance, 2.0) : 1.0
        case .calories, .carbs:
            // For calories and carbs, success is staying under the max
            return target > 0 ? min(1.0, target / dailyAverage) : 0
        case .protein:
            // For protein, success is meeting or exceeding the target
            return target > 0 ? min(dailyAverage / target, 2.0) : 0
        }
    }
    
    var isSuccessful: Bool {
        switch type {
        case .weight:
            // Successful if closer to goal than previous week
            guard let prevAvg = previousWeekAverage else { return false }
            let currentDistance = abs(dailyAverage - target)
            let previousDistance = abs(prevAvg - target)
            return currentDistance <= previousDistance
        case .calories, .carbs:
            // Successful if under the max
            return dailyAverage <= target
        case .protein:
            // Successful if meeting or exceeding target
            return dailyAverage >= target
        }
    }
    
    var progressColor: String {
        if isSuccessful {
            return "green"
        } else {
            let percentage = progressPercentage
            if percentage >= 0.8 {
                return "yellow"
            } else if percentage >= 0.6 {
                return "orange"
            } else {
                return "red"
            }
        }
    }
    
    var isCurrentWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the current week's date interval
        guard let currentWeekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return false
        }
        
        // Check if this week's start date matches the current week's start date
        return calendar.isDate(weekStartDate, equalTo: currentWeekInterval.start, toGranularity: .day)
    }
    
    var weekLabel: String {
        if isCurrentWeek {
            return "This Week"
        } else {
            let calendar = Calendar.current
            let now = Date()
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            
            // Calculate the number of weeks between the start of this week and the start of the current week
            let weeksAgo = calendar.dateComponents([.weekOfYear], from: weekStartDate, to: currentWeekStart).weekOfYear ?? 0
            
            if weeksAgo == 1 {
                return "Last Week"
            } else {
                return "\(weeksAgo) weeks ago"
            }
        }
    }
    
    var formattedValue: String {
        switch type {
        case .weight:
            return String(format: "%.1f kg", dailyAverage)
        case .calories:
            return "\(Int(dailyAverage)) cal"
        case .carbs:
            return "\(Int(dailyAverage))g"
        case .protein:
            return "\(Int(dailyAverage))g"
        }
    }
    
    var formattedTarget: String {
        switch type {
        case .weight:
            return String(format: "%.1f kg", target)
        case .calories:
            return "\(Int(target)) cal max"
        case .carbs:
            return "\(Int(target))g max"
        case .protein:
            return "\(Int(target))g target"
        }
    }
}

enum FitnessMetricType: String, CaseIterable {
    case weight = "Weight"
    case calories = "Calories"
    case carbs = "Carbs"
    case protein = "Protein"
    
    var icon: String {
        switch self {
        case .weight:
            return "scalemass"
        case .calories:
            return "flame"
        case .carbs:
            return "leaf"
        case .protein:
            return "fish"
        }
    }
    
    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .calories:
            return "cal"
        case .carbs, .protein:
            return "g"
        }
    }
} 