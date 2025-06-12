import SwiftUI

struct WeeklyFitnessView: View {
    @ObservedObject var mainViewModel: FitKingViewModel
    @StateObject private var weeklyViewModel = WeeklyFitnessViewModel()
    @Binding var selectedMetric: FitnessMetricType
    
    var body: some View {
        NavigationView {
            VStack {
                // Metric selector
                Picker("Fitness Metric", selection: $selectedMetric) {
                    ForEach(FitnessMetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue)
                            .tag(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if weeklyViewModel.isLoading {
                    WeeklyLoadingView()
                } else if let error = weeklyViewModel.error {
                    WeeklyErrorView(message: error) {
                        weeklyViewModel.refreshData(for: weeklyViewModel.selectedMetric, settings: mainViewModel.settings)
                    }
                } else {
                    WeeklyDataList(weeklyData: weeklyViewModel.weeklyData)
                }
            }
            .navigationTitle("Weekly Fitness")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                weeklyViewModel.loadWeeklyData(for: selectedMetric, settings: mainViewModel.settings)
            }
            .onChange(of: selectedMetric) { oldMetric, newMetric in
                weeklyViewModel.loadWeeklyData(for: newMetric, settings: mainViewModel.settings)
            }
            .refreshable {
                weeklyViewModel.refreshData(for: selectedMetric, settings: mainViewModel.settings)
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
    let weeklyData: [WeeklyFitnessData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(weeklyData) { week in
                    WeeklyFitnessCard(weekData: week)
                }
            }
            .padding()
        }
    }
}

private struct WeeklyFitnessCard: View {
    let weekData: WeeklyFitnessData
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
        if weekData.isSuccessful {
            return "checkmark.circle.fill"
        } else {
            // For weight, unsuccessful means moving away from goal - always X
            if weekData.type == .weight {
                return "xmark.circle.fill"
            }
            
            // For other metrics, use color-matched icons
            switch weekData.progressColor {
            case "orange":
                return "minus.circle.fill" // Mild concern - minus sign
            case "red":
                return "xmark.circle.fill" // Major concern - X mark
            default:
                return "xmark.circle.fill"
            }
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
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: weekData.type.icon)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Image(systemName: progressIcon)
                        .foregroundColor(progressColor)
                        .font(.title2)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if weekData.type == .weight {
                        if let message = weekData.weightProgressMessage {
                            Text(message)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(progressColor)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        } else {
                            Text(weekData.isSuccessful ? "Good Progress" : "Keep Working")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(progressColor)
                        }
                    } else {
                        Text(weekData.isSuccessful ? "Success" : "Needs Work")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(progressColor)
                    }
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
            
            // Fitness details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(weekData.formattedValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(progressColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(weekData.formattedTarget)
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
            
            // Weight-specific info
            if weekData.type == .weight, let prevWeight = weekData.previousWeekAverage {
                let change = weekData.dailyAverage - prevWeight
                let settings = TrackingSettings.load()
                let changeText = change >= 0 ? "+\(settings.displayWeight(abs(change)))" : "-\(settings.displayWeight(abs(change)))"
                
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Change from last week: \(changeText)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
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
    let viewModel = FitKingViewModel()
    WeeklyFitnessView(mainViewModel: viewModel, selectedMetric: .constant(.weight))
} 
