import Foundation

// Represents a week's worth of step data
struct WeeklyStepData: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let weekEndDate: Date
    let totalSteps: Int
    let dailyAverage: Int
    let daysWithData: Int
    let goalSteps: Int
    
    // Computed properties for display
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStartDate)
        let endString = formatter.string(from: weekEndDate)
        
        return "\(startString) - \(endString)"
    }
    
    var progressPercentage: Double {
        guard goalSteps > 0 else { return 0 }
        return Double(dailyAverage) / Double(goalSteps)
    }
    
    var progressColor: String {
        let percentage = progressPercentage
        
        if percentage >= 1.0 {
            return "green"
        } else if percentage >= 0.8 {
            return "yellow"
        } else if percentage >= 0.6 {
            return "orange"
        } else {
            return "red"
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
} 