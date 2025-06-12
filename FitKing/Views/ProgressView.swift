import SwiftUI
import Combine

// Extension to Double for rounding decimal numbers
// Used throughout the app for percentage calculations
extension Double {
    func rounded(to decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}

// Main this week view that shows:
// - Top row: Weekly nutrition progress with daily breakdowns
// - Bottom: Engaging weight section with trend visualization
struct ProgressView: View {
    @ObservedObject var viewModel: FitKingViewModel
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    @State private var caloriesWeekData: [DailyMetricData] = []
    @State private var carbsWeekData: [DailyMetricData] = []
    @State private var proteinWeekData: [DailyMetricData] = []
    @State private var isLoadingWeekData = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = viewModel.error {
                    ErrorView(message: error)
                } else {
                    // Header section
                    HeaderSection(viewModel: viewModel)
                        .padding(.horizontal, 16)
                    
                    // Top row: Weekly nutrition cards with daily breakdowns
                    WeeklyNutritionMetricsRow(
                        caloriesData: caloriesWeekData,
                        carbsData: carbsWeekData,
                        proteinData: proteinWeekData,
                        isLoading: isLoadingWeekData,
                        selectedTab: $selectedTab,
                        selectedMetric: $selectedMetric
                    )
                    
                    // Bottom: Engaging weight section
                    WeightDetailSection(viewModel: viewModel, selectedTab: $selectedTab, selectedMetric: $selectedMetric)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.systemGray6).opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            loadWeeklyData()
        }
    }
    
    private func loadWeeklyData() {
        let dispatchGroup = DispatchGroup()
        
        // Load calories week data
        dispatchGroup.enter()
        HealthKitManager.shared.getThisWeekDailyData(for: .calories, settings: viewModel.settings) { data, error in
            DispatchQueue.main.async {
                self.caloriesWeekData = data
                dispatchGroup.leave()
            }
        }
        
        // Load carbs week data
        dispatchGroup.enter()
        HealthKitManager.shared.getThisWeekDailyData(for: .carbs, settings: viewModel.settings) { data, error in
            DispatchQueue.main.async {
                self.carbsWeekData = data
                dispatchGroup.leave()
            }
        }
        
        // Load protein week data
        dispatchGroup.enter()
        HealthKitManager.shared.getThisWeekDailyData(for: .protein, settings: viewModel.settings) { data, error in
            DispatchQueue.main.async {
                self.proteinWeekData = data
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoadingWeekData = false
        }
    }
}

// Helper Views
// Displays error messages with:
// - Warning triangle icon
// - Error message text
// - Red color scheme for visibility
private struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.title)
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// Enhanced header with better visual appeal
private struct HeaderSection: View {
    @ObservedObject var viewModel: FitKingViewModel
    
    private var overallSuccessful: Bool {
        FitnessMetricType.allCases.allSatisfy { metric in
            viewModel.getProgressStatus(for: metric).isSuccess
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("This Week")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// Weekly nutrition cards with daily breakdowns
private struct WeeklyNutritionMetricsRow: View {
    let caloriesData: [DailyMetricData]
    let carbsData: [DailyMetricData]
    let proteinData: [DailyMetricData]
    let isLoading: Bool
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    
    var body: some View {
        HStack(spacing: 12) {
            WeeklyNutritionCard(
                metric: .calories,
                weekData: caloriesData,
                isLoading: isLoading,
                selectedTab: $selectedTab,
                selectedMetric: $selectedMetric
            )
            
            WeeklyNutritionCard(
                metric: .carbs,
                weekData: carbsData,
                isLoading: isLoading,
                selectedTab: $selectedTab,
                selectedMetric: $selectedMetric
            )
            
            WeeklyNutritionCard(
                metric: .protein,
                weekData: proteinData,
                isLoading: isLoading,
                selectedTab: $selectedTab,
                selectedMetric: $selectedMetric
            )
        }
        .padding(.horizontal, 16)
    }
}

// Weekly nutrition card showing daily progress bars
private struct WeeklyNutritionCard: View {
    let metric: FitnessMetricType
    let weekData: [DailyMetricData]
    let isLoading: Bool
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    
    private var weeklyAverage: Double {
        guard !weekData.isEmpty else { return 0 }
        let validDays = weekData.filter { $0.value > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.value } / Double(validDays.count)
    }
    
    private var weeklyTarget: Double {
        guard let firstDay = weekData.first else { return 0 }
        return firstDay.target
    }
    
    private var isWeekOnTrack: Bool {
        switch metric {
        case .calories, .carbs:
            return weeklyAverage <= weeklyTarget
        case .protein:
            return weeklyAverage >= weeklyTarget
        case .weight:
            return true
        }
    }
    
    private var cardGradient: LinearGradient {
        let baseColor: Color
        
        // Determine severity level for card color
        if isWeekOnTrack {
            baseColor = .green // Success
        } else {
            // Check if significantly over target (>20% over for calories/carbs, >20% under for protein)
            let overagePercentage = switch metric {
            case .calories, .carbs:
                (weeklyAverage - weeklyTarget) / weeklyTarget
            case .protein:
                (weeklyTarget - weeklyAverage) / weeklyTarget
            case .weight:
                0.0
            }
            
            baseColor = overagePercentage > 0.2 ? .red : .orange // Red if significantly off, orange if mildly off
        }
        
        // Much more subdued background - darker with subtle color hint
        return LinearGradient(
            colors: [
                Color(.systemGray5).opacity(0.9),
                baseColor.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Color for the average value text based on status
    private var averageTextColor: Color {
        if isWeekOnTrack {
            return .green.opacity(0.9)
        } else {
            let overagePercentage = switch metric {
            case .calories, .carbs:
                (weeklyAverage - weeklyTarget) / weeklyTarget
            case .protein:
                (weeklyTarget - weeklyAverage) / weeklyTarget
            case .weight:
                0.0
            }
            
            return overagePercentage > 0.2 ? .red.opacity(0.9) : .orange.opacity(0.9)
        }
    }
    
    private var formattedAverage: String {
        switch metric {
        case .calories:
            return "\(Int(weeklyAverage))"
        case .carbs, .protein:
            return "\(Int(weeklyAverage))g"
        case .weight:
            return ""
        }
    }
    
    private var statusText: String {
        switch metric {
        case .calories, .carbs:
            if weeklyAverage <= weeklyTarget {
                return "On track!"
            } else {
                let over = ((weeklyAverage - weeklyTarget) / weeklyTarget * 100).rounded(to: 0)
                return "\(Int(over))% over"
            }
        case .protein:
            if weeklyAverage >= weeklyTarget {
                return "Target met!"
            } else {
                let under = ((weeklyTarget - weeklyAverage) / weeklyTarget * 100).rounded(to: 0)
                return "\(Int(under))% under"
            }
        case .weight:
            return ""
        }
    }
    
    // Calculate bar height based on value relative to target
    private func getBarHeight(for day: DailyMetricData) -> CGFloat {
        guard day.target > 0 else { return 4 }
        
        let ratio = day.value / day.target
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        
        // Scale height based on ratio, with some minimum visibility
        let height = minHeight + (ratio * (maxHeight - minHeight))
        return min(maxHeight, max(minHeight, height))
    }
    
    // Get bar color based on success/failure and severity (3-color system)
    private func getBarColor(for day: DailyMetricData) -> Color {
        if day.value == 0 {
            return Color.white.opacity(0.3) // No data - subtle white
        }
        
        switch metric {
        case .calories, .carbs:
            // Success = under or at target
            if day.value <= day.target {
                return Color.green.opacity(0.9) // Success - green
            } else if day.value <= day.target * 1.2 {
                return Color.orange.opacity(0.9) // Mildly over (1-20% over) - orange
            } else {
                return Color.red.opacity(0.9) // Significantly over (>20% over) - red
            }
        case .protein:
            // Success = at or above target
            if day.value >= day.target {
                return Color.green.opacity(0.9) // Success - green
            } else if day.value >= day.target * 0.8 {
                return Color.orange.opacity(0.9) // Close to target (80-99%) - orange
            } else {
                return Color.red.opacity(0.9) // Significantly under (<80%) - red
            }
        case .weight:
            return Color.green.opacity(0.9)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                // Loading state
                VStack(spacing: 8) {
                    Image(systemName: metric.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    SwiftUI.ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                // Header with icon and metric name
                HStack {
                    Image(systemName: metric.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    
                    Text(metric.rawValue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.medium)
                }
                
                // Weekly average
                VStack(spacing: 2) {
                    Text("Avg/Day")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(formattedAverage)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(averageTextColor)
                    
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .fontWeight(.medium)
                }
                
                // Daily progress bars for the week
                VStack(spacing: 6) {
                    // Progress bars with variable heights
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(weekData.indices, id: \.self) { index in
                            if index < weekData.count {
                                let day = weekData[index]
                                let barHeight = getBarHeight(for: day)
                                let barColor = getBarColor(for: day)
                                
                                VStack(spacing: 2) {
                                    Rectangle()
                                        .fill(barColor)
                                        .frame(width: 12, height: barHeight)
                                        .cornerRadius(2)
                                    
                                    Text(day.dayOfWeek.prefix(1))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 12)
                                }
                            }
                        }
                    }
                    .frame(height: 40) // Fixed container height for bars
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(cardGradient)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            // Set the specific metric and switch to Weekly tab
            selectedMetric = metric
            selectedTab = 1
        }
        .animation(.easeInOut(duration: 0.1), value: selectedTab)
    }
}

// Detailed weight section showing 4 weeks of data
private struct WeightDetailSection: View {
    @ObservedObject var viewModel: FitKingViewModel
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    @State private var weeklyWeightData: [WeeklyFitnessData] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme
    
    private var settings: TrackingSettings {
        viewModel.settings
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var currentWeight: Double {
        viewModel.getCurrentValue(for: .weight)
    }
    
    private var targetWeight: Double {
        viewModel.getTarget(for: .weight)
    }
    
    private var overallAverage: Double {
        guard !weeklyWeightData.isEmpty else { return 0 }
        let total = weeklyWeightData.reduce(0) { $0 + $1.dailyAverage }
        return total / Double(weeklyWeightData.count)
    }
    
    private var averageWeightLoss: Double {
        guard weeklyWeightData.count >= 2 else { return 0 }
        let sortedData = weeklyWeightData.sorted { $0.weekStartDate < $1.weekStartDate }
        let firstWeek = sortedData.first!
        let lastWeek = sortedData.last!
        let totalChange = firstWeek.dailyAverage - lastWeek.dailyAverage
        let weeksBetween = weeklyWeightData.count - 1
        return weeksBetween > 0 ? totalChange / Double(weeksBetween) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Weight header
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Weight Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isLoading {
                    SwiftUI.ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if !isLoading {
                // Current weight and target
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(settings.displayWeight(currentWeight))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(settings.displayWeight(targetWeight))
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                }
                
                // 4-week average summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 4 Weeks Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Average Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(settings.displayWeight(overallAverage))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Avg Change/Week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let changeText = averageWeightLoss > 0 ? 
                                "-\(settings.displayWeight(averageWeightLoss))" : 
                                averageWeightLoss < 0 ? 
                                "+\(settings.displayWeight(abs(averageWeightLoss)))" : 
                                "No change"
                            
                            Text(changeText)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(averageWeightLoss > 0 ? .green : 
                                               averageWeightLoss < 0 ? .red : .orange)
                        }
                    }
                }
                
                // Weekly breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Breakdown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(weeklyWeightData.sorted { $0.weekStartDate > $1.weekStartDate }) { week in
                        WeeklyWeightRow(weekData: week, settings: settings)
                    }
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .onTapGesture {
            // Set weight metric and switch to Weekly tab
            selectedMetric = .weight
            selectedTab = 1
        }
        .onAppear {
            loadWeightData()
        }
    }
    
    private func loadWeightData() {
        let settings = TrackingSettings.load()
        HealthKitManager.shared.getWeeklyFitnessData(for: .weight, weeks: 5, settings: settings) { data, error in
            DispatchQueue.main.async {
                // Take only the first 4 weeks for display, but we have 5 weeks for calculations
                self.weeklyWeightData = Array(data.prefix(4))
                self.isLoading = false
            }
        }
    }
}

// Individual weekly weight row
private struct WeeklyWeightRow: View {
    let weekData: WeeklyFitnessData
    let settings: TrackingSettings
    
    private var changeText: String? {
        guard let prevWeight = weekData.previousWeekAverage else { return nil }
        let change = weekData.dailyAverage - prevWeight
        if abs(change) < 0.1 { return nil } // Don't show very small changes
        return change > 0 ? "+\(settings.displayWeight(abs(change)))" : "-\(settings.displayWeight(abs(change)))"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekData.weekLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(weekData.dateRange)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.displayWeight(weekData.dailyAverage))
                    .font(.caption)
                    .fontWeight(.bold)
                
                if let change = changeText {
                    Text(change)
                        .font(.caption2)
                        .foregroundColor(change.hasPrefix("+") ? .red : .green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let viewModel = FitKingViewModel()
    ProgressView(viewModel: viewModel, selectedTab: .constant(0), selectedMetric: .constant(.weight))
} 
