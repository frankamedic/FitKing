import Foundation

extension DefaultStringInterpolation {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    mutating func appendInterpolation(_ value: Any) {
        let timestamp = DefaultStringInterpolation.timeFormatter.string(from: Date())
        appendLiteral("[\(timestamp)] ")
        appendLiteral(String(describing: value))
    }
} 