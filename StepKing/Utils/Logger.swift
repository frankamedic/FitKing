import Foundation

// Preserve the original print function
public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let output = items.map { "\($0)" }.joined(separator: separator)
    // Use Swift.print directly to avoid recursion
    Swift.print("[\(timestamp)] \(output)", terminator: terminator)
} 