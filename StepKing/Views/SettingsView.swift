import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StepKingViewModel
    
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
                        set: { viewModel.settings.endTime = $0 }
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
    }
}
