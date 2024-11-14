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
                    step: 1000
                )
            }
            
            Section(header: Text("Notifications")) {
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
            }
            
            Section("Notifications") {
                Button("Send Test Notification") {
                    sendTestNotification()
                }
            }
        }
    }
    
    private func sendTestNotification() {
        print("🔔 Sending test notification...")
        let now = Date()
        let testDate = now.addingTimeInterval(5)
        
        NotificationManager.shared.scheduleStepProgressNotification(
            currentSteps: viewModel.currentSteps,
            goalSteps: viewModel.settings.dailyStepGoal,
            endTime: viewModel.settings.todayEndTime,
            date: testDate,
            isTest: true
        )
    }
} 
