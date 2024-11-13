import Foundation

struct TrackingSettings: Codable {
    var startTime: Date
    var endTime: Date
    var dailyStepGoal: Int
    var notificationFrequency: TimeInterval // in minutes
    
    static let `default` = TrackingSettings(
        startTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
        endTime: Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date(),
        dailyStepGoal: 10000,
        notificationFrequency: 60
    )
    
    // Add this computed property to always get today's date with the configured time
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
        let start = calendar.dateComponents([.hour, .minute], from: startTime)
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let nowMinutes = now.hour! * 60 + now.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }
    
    func expectedProgress(at date: Date = Date()) -> Double {
        guard isWithinTrackingPeriod(date) else { return 0 }
        
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: date)
        let start = calendar.dateComponents([.hour, .minute], from: startTime)
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let nowMinutes = now.hour! * 60 + now.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        let totalMinutes = endMinutes - startMinutes
        let elapsedMinutes = nowMinutes - startMinutes
        
        return Double(elapsedMinutes) / Double(totalMinutes)
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
