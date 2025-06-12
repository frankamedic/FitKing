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

// Main today view that shows:
// - Top row: Visually appealing nutrition cards with progress rings
// - Bottom: Engaging weight section with trend visualization
struct ProgressView: View {
    @ObservedObject var viewModel: FitKingViewModel
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = viewModel.error {
                    ErrorView(message: error)
                } else {
                    // Header section
                    HeaderSection(viewModel: viewModel)
                    
                    // Top row: Nutrition cards with progress rings
                    NutritionMetricsRow(viewModel: viewModel, selectedTab: $selectedTab, selectedMetric: $selectedMetric)
                    
                    // Bottom: Engaging weight section
                    WeightDetailSection(viewModel: viewModel, selectedTab: $selectedTab, selectedMetric: $selectedMetric)
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.systemGray6).opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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
            Text("Today")
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

// Enhanced nutrition cards with progress rings
private struct NutritionMetricsRow: View {
    @ObservedObject var viewModel: FitKingViewModel
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    
    let nutritionMetrics: [FitnessMetricType] = [.calories, .carbs, .protein]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(nutritionMetrics, id: \.self) { metric in
                EnhancedNutritionCard(
                    metric: metric,
                    current: viewModel.getCurrentValue(for: metric),
                    target: viewModel.getTarget(for: metric),
                    status: viewModel.getProgressStatus(for: metric),
                    settings: viewModel.settings,
                    selectedTab: $selectedTab,
                    selectedMetric: $selectedMetric
                )
            }
        }
    }
}

// Visually appealing nutrition card with progress ring
private struct EnhancedNutritionCard: View {
    let metric: FitnessMetricType
    let current: Double
    let target: Double
    let status: ProgressStatus
    let settings: TrackingSettings
    @Binding var selectedTab: Int
    @Binding var selectedMetric: FitnessMetricType
    
    private var progressPercentage: Double {
        switch metric {
        case .calories, .carbs:
            return min(current / target, 1.5) // Cap at 150% for visual purposes
        case .protein:
            return min(current / target, 1.5)
        case .weight:
            return 0
        }
    }
    
    private var cardGradient: LinearGradient {
        switch metric {
        case .calories:
            return LinearGradient(
                colors: status.isSuccess ? [.green.opacity(0.8), .mint.opacity(0.6)] : [.orange.opacity(0.8), .red.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .carbs:
            return LinearGradient(
                colors: status.isSuccess ? [.green.opacity(0.8), .yellow.opacity(0.6)] : [.orange.opacity(0.8), .red.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .protein:
            return LinearGradient(
                colors: status.isSuccess ? [.blue.opacity(0.8), .purple.opacity(0.6)] : [.orange.opacity(0.8), .red.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .weight:
            return LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var formattedCurrent: String {
        switch metric {
        case .calories:
            return "\(Int(current))"
        case .carbs, .protein:
            return "\(Int(current))g"
        case .weight:
            return ""
        }
    }
    
    private var progressText: String {
        switch metric {
        case .calories, .carbs:
            if current <= target {
                let remaining = target - current
                let percentage = (remaining / target * 100).rounded(to: 0)
                return "\(Int(percentage))% left"
            } else {
                let over = current - target
                let percentage = (over / target * 100).rounded(to: 0)
                return "\(Int(percentage))% over"
            }
        case .protein:
            if current >= target {
                let over = current - target
                let percentage = (over / target * 100).rounded(to: 0)
                return "\(Int(percentage))% over"
            } else {
                let remaining = target - current
                let percentage = (remaining / target * 100).rounded(to: 0)
                return "\(Int(percentage))% left"
            }
        case .weight:
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress ring with icon
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: min(progressPercentage, 1.0))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progressPercentage)
                
                // Icon
                Image(systemName: metric.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            
            // Metric info
            VStack(spacing: 4) {
                Text(metric.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .fontWeight(.medium)
                
                Text(formattedCurrent)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(progressText)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .fontWeight(.medium)
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
        .scaleEffect(1.0)
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
