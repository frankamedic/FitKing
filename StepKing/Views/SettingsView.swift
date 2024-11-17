import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StepKingViewModel
    @State private var showToast = false
    @State private var toastMessage = ""
    
    private func adjustEndTimeIfMidnight(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        // If both hour and minute are 0 (midnight), adjust to 23:59
        if components.hour == 0 && components.minute == 0 {
            print("Midnight detected - adjusting to 23:59")
            
            // Create 23:59 using today's date
            var newComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            newComponents.hour = 23
            newComponents.minute = 59
            newComponents.second = 0
            
            let adjustedDate = calendar.date(from: newComponents) ?? date
            
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let formattedTime = formatter.string(from: adjustedDate)
            
            DispatchQueue.main.async {
                toastMessage = "Midnight is tomorrow - using \(formattedTime) instead"
                withAnimation {
                    showToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
            return adjustedDate
        }
        return date
    }
    
    var body: some View {
        Form {
            Section(header: Text("Goal Window")) {
                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { viewModel.settings.startTime },
                        set: { viewModel.settings.startTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                
                DatePicker(
                    "End Time",
                    selection: Binding(
                        get: { viewModel.settings.endTime },
                        set: { 
                            print("End time selected: \($0)") // Debug print
                            viewModel.settings.endTime = adjustEndTimeIfMidnight($0)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            
            Section(header: Text("Goal")) {
                Stepper(
                    "Daily Step Goal: \(viewModel.settings.dailyStepGoal)",
                    value: Binding(
                        get: { viewModel.settings.dailyStepGoal },
                        set: { viewModel.settings.dailyStepGoal = $0 }
                    ),
                    step: 100
                )
            }
            
            Section(
                header: Text("Notifications"),
                footer: Text("StepKing partners with you by checking your progress in the background. If you're behind on your daily step goal, you'll get nudged during your goal window. You're in control - you won't get nudged more often than you chose, and only when you need that extra help to reach your goal.")
            ) {
                Picker(
                    "Nudge Me Every",
                    selection: Binding(
                        get: { viewModel.settings.notificationFrequency },
                        set: { viewModel.settings.notificationFrequency = $0 }
                    )
                ) {
                    Text("1 minute").tag(TimeInterval(1))
                    Text("5 minutes").tag(TimeInterval(5))
                    Text("15 minutes").tag(TimeInterval(15))
                    Text("30 minutes").tag(TimeInterval(30))
                    Text("1 hour").tag(TimeInterval(60))
                    Text("2 hours").tag(TimeInterval(120))
                }
                
                NextNotificationView()
            }
        }
        .overlay(
            Group {
                if showToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top))
                }
            }
        )
    }
}
