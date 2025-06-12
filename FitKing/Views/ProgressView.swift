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

// Main progress view that shows:
// - Current fitness metrics and targets
// - Progress visualization for each metric
// - Time remaining information
// - Success/warning indicators
struct ProgressView: View {
    @ObservedObject var viewModel: FitKingViewModel
    
    // Main view layout:
    // - Shows error view if there's an error
    // - Displays current progress section for all metrics
    // - Shows time info and motivational messages
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = viewModel.error {
                    ErrorView(message: error)
                } else {
                    // Header section
                    HeaderSection(viewModel: viewModel)
                    
                    // Fitness metrics grid
                    FitnessMetricsGrid(viewModel: viewModel)
                    
                    // Time info section
                    TimeSection(viewModel: viewModel)
                }
            }
            .padding()
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

// Shows header information and overall success status
private struct HeaderSection: View {
    @ObservedObject var viewModel: FitKingViewModel
    
    private var overallSuccessful: Bool {
        FitnessMetricType.allCases.allSatisfy { metric in
            viewModel.getProgressStatus(for: metric).isSuccess
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if overallSuccessful {
                Text("👑")
                    .font(.system(size: 64))
                
                Text("🎉 All Goals Met! 🎉")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            } else {
                Text("💪")
                    .font(.system(size: 64))
                
                Text("Today's Progress")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Text("Keep tracking your fitness goals")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// Displays all fitness metrics in a grid layout
private struct FitnessMetricsGrid: View {
    @ObservedObject var viewModel: FitKingViewModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(FitnessMetricType.allCases, id: \.self) { metric in
                FitnessMetricCard(
                    metric: metric,
                    current: viewModel.getCurrentValue(for: metric),
                    target: viewModel.getTarget(for: metric),
                    status: viewModel.getProgressStatus(for: metric)
                )
            }
        }
    }
}

// Individual metric card showing current value, target, and progress
private struct FitnessMetricCard: View {
    let metric: FitnessMetricType
    let current: Double
    let target: Double
    let status: ProgressStatus
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var progressColor: Color {
        Color(status.color == "green" ? .green : 
              status.color == "yellow" ? .yellow : 
              status.color == "orange" ? .orange : .red)
    }
    
    private var formattedCurrent: String {
        switch metric {
        case .weight:
            return String(format: "%.1f kg", current)
        case .calories:
            return "\(Int(current)) cal"
        case .carbs, .protein:
            return "\(Int(current))g"
        }
    }
    
    private var formattedTarget: String {
        switch metric {
        case .weight:
            return String(format: "%.1f kg", target)
        case .calories:
            return "\(Int(target)) cal max"
        case .carbs:
            return "\(Int(target))g max"
        case .protein:
            return "\(Int(target))g target"
        }
    }
    
    private var statusText: String {
        switch metric {
        case .weight:
            let distance = abs(current - target)
            if distance <= 1.0 {
                return "On Target"
            } else {
                return String(format: "%.1f kg away", distance)
            }
        case .calories, .carbs:
            if current <= target {
                return "Under Limit"
            } else {
                return "Over Limit"
            }
        case .protein:
            if current >= target {
                return "Target Met"
            } else {
                return "\(Int(target - current))g needed"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: metric.icon)
                    .foregroundColor(progressColor)
                    .font(.title2)
                
                Text(metric.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: status.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(progressColor)
                    .font(.title3)
            }
            
            // Current value
            HStack {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formattedCurrent)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
            }
            
            // Target value
            HStack {
                Text("Target")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formattedTarget)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Progress bar (for protein and calories/carbs)
            if metric == .protein || metric == .calories || metric == .carbs {
                VStack(spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(min(status.percentage * 100, 100)))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(progressColor)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(progressColor)
                                .frame(
                                    width: geometry.size.width * min(status.percentage, 1.0),
                                    height: 4
                                )
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(progressColor)
                .fontWeight(.medium)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

// Displays time-related information and motivational messages
private struct TimeSection: View {
    @ObservedObject var viewModel: FitKingViewModel
    
    // Timer management using Combine
    // Updates every second for smooth countdown
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common)
    @State private var timerCancellable: AnyCancellable?
    
    // Gets end time from settings
    private var endTime: Date {
        viewModel.settings.todayEndTime
    }
    
    // Calculates remaining time until end time
    private var timeRemaining: TimeInterval {
        currentTime.distance(to: endTime)
    }
    
    // Formats remaining time as HH:MM:SS
    // Shows "Time's up!" when time has expired
    private var formattedTimeRemaining: String {
        if timeRemaining <= 0 {
            return "Day complete!"
        }
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Provides motivational messages based on progress
    private var motivationalMessage: String {
        let successfulMetrics = FitnessMetricType.allCases.filter { metric in
            viewModel.getProgressStatus(for: metric).isSuccess
        }
        
        if successfulMetrics.count == FitnessMetricType.allCases.count {
            return "Amazing! All your fitness goals are on track! 🎉"
        } else if successfulMetrics.count >= 3 {
            return "Great progress! You're doing well with most of your goals! 💪"
        } else if successfulMetrics.count >= 2 {
            return "Good work! Keep focusing on your remaining goals! 👍"
        } else if successfulMetrics.count >= 1 {
            return "You're getting started! Focus on improving other metrics! 🌟"
        } else {
            return "Let's get moving! Every step towards your goals counts! 🚀"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Time remaining
            VStack(spacing: 8) {
                Text("Time Remaining Today")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(formattedTimeRemaining)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Motivational message
            VStack(spacing: 8) {
                Text("Daily Motivation")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(motivationalMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .onAppear {
            // Start the timer when view appears
            timerCancellable = timer.connect()
        }
        .onDisappear {
            // Stop the timer when view disappears
            timerCancellable?.cancel()
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}

#Preview {
    let viewModel = FitKingViewModel()
    ProgressView(viewModel: viewModel)
} 
