import Foundation

struct TrackingSettings: Codable {
    var startTime: Date
    var endTime: Date
    var dailyStepGoal: Int
    var notificationFrequency: TimeInterval // in minutes
    
    static let `default` = TrackingSettings(
        startTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
        endTime: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
        dailyStepGoal: 10000,
        notificationFrequency: 60
    )
    
    // Add this computed property to always get today's date with the configured time
    var todayStartTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        components.hour = startTimeComponents.hour
        components.minute = startTimeComponents.minute
        return calendar.date(from: components) ?? Date()
    }
    
    var todayEndTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        components.hour = endTimeComponents.hour
        components.minute = endTimeComponents.minute
        return calendar.date(from: components) ?? Date()
    }
    
    // Helper methods for time calculations
    func isWithinTrackingPeriod(_ date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: date)
        let start = calendar.dateComponents([.hour, .minute], from: todayStartTime)
        let end = calendar.dateComponents([.hour, .minute], from: todayEndTime)
        
        let nowMinutes = now.hour! * 60 + now.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }
    
    func expectedProgress(at date: Date = Date()) -> Double {
        guard isWithinTrackingPeriod(date) else { return 0 }
        
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: date)
        let start = calendar.dateComponents([.hour, .minute], from: todayStartTime)
        let end = calendar.dateComponents([.hour, .minute], from: todayEndTime)
        
        let nowMinutes = now.hour! * 60 + now.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        let totalMinutes = endMinutes - startMinutes
        let elapsedMinutes = nowMinutes - startMinutes
        
        return Double(elapsedMinutes) / Double(totalMinutes)
    }
    
    func nextTrackingPeriodStart() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's start time
        var todayStart = calendar.startOfDay(for: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute else {
            return nil
        }
        
        todayStart = calendar.date(bySettingHour: startHour,
                                 minute: startMinute,
                                 second: 0,
                                 of: todayStart) ?? todayStart
        
        // If we haven't passed today's start time yet, return it
        if now < todayStart {
            return todayStart
        }
        
        // Otherwise, return tomorrow's start time
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return nil
        }
        
        return tomorrowStart
    }
}

// Extension for UserDefaults persistence
extension TrackingSettings {
    private static let settingsKey = "com.stepking.settings"
    
    static func load() -> TrackingSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(TrackingSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }
} 
