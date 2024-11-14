import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StepKingViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Notification Period")) {
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
            
            Section(header: Text("Goals")) {
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
                footer: Text("Check times are approximate and rely on iOS. Notifications can be triggered by changes in your step count or iOS-managed timed background checks of your step progress. They will never occur more frequently than you specify above, and notifications will only be sent during your tracking period.")
            ) {
                Picker(
                    "Check Frequency",
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
