import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FitKingViewModel
    @State private var showToast = false
    @State private var toastMessage = ""
    
    private func adjustEndTimeIfMidnight(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        // If both hour and minute are 0 (midnight), adjust to 23:59
        if components.hour == 0 && components.minute == 0 {
            print("Midnight detected - adjusting to 23:59")
            
            // Use the original date as base and just modify the time components
            let adjustedDate = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date
            
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
            Section(header: Text("Tracking Window")) {
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
            
            Section(header: Text("Weight Goal")) {
                HStack {
                    Text("Goal Weight")
                    Spacer()
                    TextField(
                        "70.0",
                        value: Binding(
                            get: { viewModel.settings.goalWeight },
                            set: { viewModel.settings.goalWeight = $0 }
                        ),
                        format: .number.precision(.fractionLength(1))
                    )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    
                    Text("kg")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Nutrition Limits")) {
                HStack {
                    Text("Max Daily Calories")
                    Spacer()
                    TextField(
                        "2000",
                        value: Binding(
                            get: { viewModel.settings.maxDailyCalories },
                            set: { viewModel.settings.maxDailyCalories = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    
                    Text("cal")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Max Daily Carbs")
                    Spacer()
                    TextField(
                        "250",
                        value: Binding(
                            get: { viewModel.settings.maxDailyCarbs },
                            set: { viewModel.settings.maxDailyCarbs = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    
                    Text("g")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Target Protein")
                    Spacer()
                    TextField(
                        "150",
                        value: Binding(
                            get: { viewModel.settings.targetProtein },
                            set: { viewModel.settings.targetProtein = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    
                    Text("g")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(
                header: Text("Notifications"),
                footer: Text("FitKing partners with you by checking your progress in the background. If you're behind on your fitness goals, you'll get nudged during your tracking window. You're in control - you won't get nudged more often than you chose, and only when you need that extra help to reach your goals.")
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
            
            Section(header: Text("Tips")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Fitness Tips")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("• Log meals in Health app for accurate calorie & macro tracking")
                    Text("• Weigh yourself consistently at the same time each day")
                    Text("• Use HealthKit-compatible apps for seamless data sync")
                    Text("• Set realistic goals that you can maintain long-term")
                }
                .font(.caption)
                .foregroundColor(.secondary)
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
