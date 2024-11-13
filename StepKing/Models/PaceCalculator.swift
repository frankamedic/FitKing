import Foundation

struct PaceOption {
    let name: String
    let icon: String  // Emoji string
    let stepsPerHour: Int
    let timeNeeded: TimeInterval
    
    static func calculateTimeNeeded(stepsNeeded: Int, stepsPerHour: Int) -> TimeInterval {
        Double(stepsNeeded) / Double(stepsPerHour) * 3600
    }
}

struct PaceCalculator {
    static let paceOptions = [
        (name: "Slow pace (2 mph)", icon: "🐢", stepsPerHour: 3600),
        (name: "Moderate pace (3 mph)", icon: "🦊", stepsPerHour: 4800),
        (name: "Brisk pace (4 mph)", icon: "🐆", stepsPerHour: 8000)
    ]
    
    static func calculatePaceOptions(stepsNeeded: Int) -> [PaceOption] {
        paceOptions.map { pace in
            let timeNeeded = PaceOption.calculateTimeNeeded(stepsNeeded: stepsNeeded, stepsPerHour: pace.stepsPerHour)
            return PaceOption(
                name: pace.name,
                icon: pace.icon,
                stepsPerHour: pace.stepsPerHour,
                timeNeeded: timeNeeded
            )
        }
    }
    
    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
} 