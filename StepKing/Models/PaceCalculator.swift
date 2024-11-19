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
        (name: "Very slow walk (1 mph)", icon: "🦥", stepsPerHour: 2000),
        (name: "Slow walk (2.5 mph)", icon: "🐢", stepsPerHour: 5000),
        (name: "Normal walk (3.5 mph)", icon: "🐨", stepsPerHour: 7000),
        (name: "Power walk (4.5 mph)", icon: "🦘", stepsPerHour: 9000),
        (name: "Slow jog (5.5 mph)", icon: "🦊", stepsPerHour: 11000)
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