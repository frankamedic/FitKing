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
                Picker("Weight Unit", selection: Binding(
                    get: { viewModel.settings.weightUnit },
                    set: { viewModel.settings.weightUnit = $0 }
                )) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                
                HStack {
                    Text("Goal Weight")
                    Spacer()
                    Picker("Goal Weight", selection: Binding(
                        get: { 
                            return Int(viewModel.settings.goalWeight) // Whole numbers only
                        },
                        set: { 
                            viewModel.settings.goalWeight = Double($0)
                        }
                    )) {
                        if viewModel.settings.weightUnit == .kilograms {
                            ForEach(30...150, id: \.self) { weight in
                                Text("\(weight) kg")
                                    .tag(weight)
                            }
                        } else {
                            ForEach(66...330, id: \.self) { weight in
                                Text("\(weight) lbs")
                                    .tag(weight)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            Section(header: Text("Nutrition Limits")) {
                HStack {
                    Text("Max Daily Calories")
                    Spacer()
                    Picker("Max Daily Calories", selection: Binding(
                        get: { viewModel.settings.maxDailyCalories },
                        set: { viewModel.settings.maxDailyCalories = $0 }
                    )) {
                        ForEach(Array(stride(from: 1000, through: 4000, by: 50)), id: \.self) { calories in
                            Text("\(calories) cal").tag(calories)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Max Daily Carbs")
                    Spacer()
                    Picker("Max Daily Carbs", selection: Binding(
                        get: { viewModel.settings.maxDailyCarbs },
                        set: { viewModel.settings.maxDailyCarbs = $0 }
                    )) {
                        ForEach(Array(stride(from: 0, through: 500, by: 10)), id: \.self) { carbs in
                            Text("\(carbs) g").tag(carbs)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Target Protein")
                    Spacer()
                    Picker("Target Protein", selection: Binding(
                        get: { viewModel.settings.targetProtein },
                        set: { viewModel.settings.targetProtein = $0 }
                    )) {
                        ForEach(Array(stride(from: 50, through: 300, by: 5)), id: \.self) { protein in
                            Text("\(protein) g").tag(protein)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
