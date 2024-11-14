import SwiftUI

struct NextNotificationView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var nextNotificationTime: Date? {
        NotificationManager.shared.nextNotificationTime
    }
    
    private var timeUntilNextNotification: TimeInterval? {
        guard let nextTime = nextNotificationTime else { return nil }
        return nextTime.timeIntervalSince(currentTime)
    }
    
    private var formattedNextTime: String {
        guard let nextTime = nextNotificationTime else {
            return "None scheduled"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: nextTime)
    }
    
    private var formattedTimeUntil: String {
        guard let timeUntil = timeUntilNextNotification else { return "" }
        
        if timeUntil <= 0 {
            return "Due now"
        }
        
        let minutes = Int(timeUntil) / 60
        return "\(minutes)m"
    }
    
    var body: some View {
        HStack {
            Text("Next check:")
                .foregroundColor(.secondary)
            Spacer()
            if timeUntilNextNotification != nil {
                Text(formattedNextTime)
                Text("(\(formattedTimeUntil))")
                    .foregroundColor(.secondary)
            } else {
                Text(formattedNextTime)
                    .foregroundColor(.secondary)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}

#Preview {
    NextNotificationView()
        .padding()
        .background(Color(.systemGroupedBackground))
} 