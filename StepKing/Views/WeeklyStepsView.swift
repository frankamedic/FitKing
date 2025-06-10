import SwiftUI

struct WeeklyStepsView: View {
    @ObservedObject var mainViewModel: StepKingViewModel
    @StateObject private var weeklyViewModel = WeeklyStepsViewModel()
    
    var body: some View {
        NavigationView {
                    VStack {
            if weeklyViewModel.isLoading {
                WeeklyLoadingView()
            } else if let error = weeklyViewModel.error {
                WeeklyErrorView(message: error) {
                    weeklyViewModel.refreshData(goalSteps: mainViewModel.settings.dailyStepGoal)
                }
            } else {
                WeeklyDataList(weeklyData: weeklyViewModel.weeklyData)
            }
        }
            .navigationTitle("Weekly Steps")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                weeklyViewModel.loadWeeklyData(goalSteps: mainViewModel.settings.dailyStepGoal)
            }
            .refreshable {
                weeklyViewModel.refreshData(goalSteps: mainViewModel.settings.dailyStepGoal)
            }
        }
    }
}

// MARK: - Supporting Views

private struct WeeklyLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            SwiftUI.ProgressView()
                .scaleEffect(1.5)
            Text("Loading weekly data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WeeklyErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.system(size: 48))
            
            Text("Error Loading Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WeeklyDataList: View {
    let weeklyData: [WeeklyStepData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(weeklyData) { week in
                    WeeklyStepCard(weekData: week)
                }
            }
            .padding()
        }
    }
}

private struct WeeklyStepCard: View {
    let weekData: WeeklyStepData
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var progressColor: Color {
        switch weekData.progressColor {
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        default:
            return .red
        }
    }
    
    private var progressIcon: String {
        let percentage = weekData.progressPercentage
        if percentage >= 1.0 {
            return "checkmark.circle.fill"
        } else if percentage >= 0.8 {
            return "checkmark.circle"
        } else if percentage >= 0.6 {
            return "minus.circle"
        } else {
            return "xmark.circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with week label and date range
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekData.weekLabel)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(weekData.dateRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: progressIcon)
                    .foregroundColor(progressColor)
                    .font(.title2)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(weekData.progressPercentage * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(progressColor)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(progressColor)
                            .frame(
                                width: geometry.size.width * min(weekData.progressPercentage, 1.0),
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
            
            // Step details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(weekData.dailyAverage)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(progressColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(weekData.goalSteps)")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Days Tracked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(weekData.daysWithData)")
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            
            // Additional info for current week
            if weekData.isCurrentWeek {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Current week in progress")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

#Preview {
    let viewModel = StepKingViewModel()
    WeeklyStepsView(mainViewModel: viewModel)
} 
