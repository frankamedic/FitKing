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
            guard let prevAvg = previousWeekAverage else { return false }
            let settings = TrackingSettings.load()
            let change = dailyAverage - prevAvg
            let absChange = abs(change)
            let currentDistance = abs(dailyAverage - target)
            let previousDistance = abs(prevAvg - target)
            
            // Thresholds for determining success
            let changeThreshold = settings.weightUnit == .kilograms ? 0.5 : 1.0
            let goalThreshold = settings.weightUnit == .kilograms ? 2.0 : 4.0
            
            // If already at goal, success is maintaining (small change)
            if currentDistance <= goalThreshold {
                return absChange <= changeThreshold
            }
            
            // Determine if weight is moving in the right direction toward goal
            let isLosingWeight = change < 0
            let isGainingWeight = change > 0
            let shouldLoseWeight = dailyAverage > target
            let shouldGainWeight = dailyAverage < target
            
            // Success if:
            // 1. Maintained weight (very small change)
            // 2. Lost weight when should lose weight
            // 3. Gained weight when should gain weight
            // 4. Moved closer to goal overall
            if absChange <= changeThreshold {
                return true // Maintained weight
            } else if shouldLoseWeight && isLosingWeight {
                return true // Lost weight when needed
            } else if shouldGainWeight && isGainingWeight {
                return true // Gained weight when needed
            } else {
                return currentDistance < previousDistance // At least moved closer to goal
            }
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
            // For weight, unsuccessful means moving away from goal - always red
            if type == .weight {
                return "red"
            }
            
            // For other metrics, use 3-color system matching "This Week" view
            let overagePercentage = switch type {
            case .calories, .carbs:
                // How much over the limit they are
                max(0, (dailyAverage - target) / target)
            case .protein:
                // How much under the target they are
                max(0, (target - dailyAverage) / target)
            case .weight:
                0.0
            }
            
            // Use severity-based coloring
            if overagePercentage <= 0.2 {
                return "orange" // Mildly over/under target (0-20%)
            } else {
                return "red" // Significantly over/under target (>20%)
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
            let settings = TrackingSettings.load()
            return settings.displayWeight(dailyAverage)
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
            let settings = TrackingSettings.load()
            return settings.displayWeight(target)
        case .calories:
            return "\(Int(target)) cal max"
        case .carbs:
            return "\(Int(target))g max"
        case .protein:
            return "\(Int(target))g target"
        }
    }
    
    var weightProgressMessage: String? {
        guard type == .weight, let prevAvg = previousWeekAverage else { return nil }
        
        let settings = TrackingSettings.load()
        let change = dailyAverage - prevAvg
        let absChange = abs(change)
        let currentDistance = abs(dailyAverage - target)
        
        // Thresholds for determining messages
        let changeThreshold = settings.weightUnit == .kilograms ? 0.5 : 1.0
        let goalThreshold = settings.weightUnit == .kilograms ? 2.0 : 4.0
        
        // Determine direction needed
        let shouldLoseWeight = dailyAverage > target
        let shouldGainWeight = dailyAverage < target
        
        if absChange < changeThreshold {
            // Maintained weight
            if currentDistance <= goalThreshold {
                return "Excellent! You're maintaining your weight at your goal!"
            } else {
                return "Great work, you maintained your average weight this week!"
            }
        } else if change < 0 {
            // Weight decreased
            if currentDistance <= goalThreshold {
                return "Perfect! You reached your goal weight this week!"
            } else if shouldLoseWeight {
                return "Great work, your average weight decreased \(settings.displayWeight(absChange)) this week!"
            } else {
                return "Your average weight decreased \(settings.displayWeight(absChange)) this week"
            }
        } else {
            // Weight increased
            if shouldGainWeight && currentDistance <= goalThreshold {
                return "Perfect! You reached your goal weight this week!"
            } else if shouldGainWeight {
                return "Great work, your average weight increased \(settings.displayWeight(absChange)) this week!"
            } else {
                return "Your average weight increased \(settings.displayWeight(absChange)) this week"
            }
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