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
// - Current step count and goal
// - Progress visualization
// - Time remaining information
// - Different pace options to reach goal
struct ProgressView: View {
    @ObservedObject var viewModel: StepKingViewModel
    
    // Calculates remaining steps needed to reach daily goal
    // Returns 0 if goal is already met
    private var stepsNeeded: Int {
        max(0, viewModel.settings.dailyStepGoal - viewModel.currentSteps)
    }
    
    // Gets available pace options based on remaining steps
    // Uses PaceCalculator to determine different walking speeds
    private var paceOptions: [PaceOption] {
        PaceCalculator.calculatePaceOptions(stepsNeeded: stepsNeeded)
    }
    
    // Main view layout:
    // - Shows error view if there's an error
    // - Displays current progress section
    // - Shows time info if steps are still needed
    // - Lists pace options if steps are still needed
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = viewModel.error {
                    ErrorView(message: error)
                } else {
                    // Current Progress Section
                    ProgressSection(
                        currentSteps: viewModel.currentSteps,
                        goalSteps: viewModel.settings.dailyStepGoal
                    )
                    
                    // Time Info Section
                    if stepsNeeded > 0 {
                        TimeSection(
                            endTime: viewModel.settings.todayEndTime,
                            stepsNeeded: stepsNeeded,
                            currentSteps: viewModel.currentSteps,
                            goalSteps: viewModel.settings.dailyStepGoal,
                            viewModel: viewModel
                        )
                        
                        // Pace Options Section
                        PaceOptionsSection(paceOptions: paceOptions)
                    }
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

// Shows current progress information:
// - Celebration view if goal is reached
// - Current step count
// - Daily step goal
// - Visual indicators of completion
private struct ProgressSection: View {
    let currentSteps: Int
    let goalSteps: Int
    
    // Determines if user has reached their daily goal
    private var hasReachedGoal: Bool {
        currentSteps >= goalSteps
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if hasReachedGoal {
                CelebrationView()
                    .frame(height: 200)
                
                Text("Goal Reached! ")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Text("Steps Today")
                .font(.title)
            
            Text("\(currentSteps)")
                .font(.system(size: 48, weight: .bold))
            
            Text("Goal: \(goalSteps) steps")
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }
}

// Displays time-related information:
// - Time remaining until end of tracking period (HH:MM:SS.T format)
// - Progress bar with expected vs actual progress 
// - Required pace to reach goal 
// - Motivational messages based on progress
private struct TimeSection: View {
    let endTime: Date
    let stepsNeeded: Int
    let currentSteps: Int
    let goalSteps: Int
    @ObservedObject var viewModel: StepKingViewModel
    
    // Timer management using Combine
    // Updates every 0.1 seconds for smooth countdown
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common)
    @State private var timerCancellable: AnyCancellable?
    
    // Gets start time from settings
    private var startTime: Date {
        viewModel.settings.todayStartTime
    }
    
    // Calculates remaining time until end time
    private var timeRemaining: TimeInterval {
        currentTime.distance(to: endTime)
    }
    
    // Formats remaining time as HH:MM:SS.T
    // Shows "Time's up!" when time has expired
    private var formattedTimeRemaining: String {
        if timeRemaining <= 0 {
            return "Time's up!"
        }
        let totalTenths = Int(timeRemaining * 10) // Just tenths of seconds
        let hours = totalTenths / 36_000
        let minutes = (totalTenths % 36_000) / 600
        let seconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10
        
        return String(format: "%02d:%02d:%02d.%01d", hours, minutes, seconds, tenths)
    }
    
    // Calculates expected progress based on time of day
    private var expectedProgress: Double {
        if timeRemaining <= 0 {
            return 1.0  // 100% expected when past end time
        }
        return viewModel.settings.expectedProgress()
    }
    
    // Determines if user is ahead of their expected progress
    private var isAheadOfSchedule: Bool {
        Double(currentSteps) / Double(goalSteps) >= expectedProgress
    }
    
    // Provides context-appropriate motivational messages
    // Based on time remaining and progress
    private var motivationalMessage: String {
        if timeRemaining <= 0 {
            let stepsPercent = Int(Double(currentSteps) / Double(goalSteps) * 100)
            if stepsPercent >= 100 {
                return "Great job completing your steps today! 🎉"
            } else {
                return "You can still reach your goal before midnight! 💪"
            }
        }
        return ""
    }
    
    // Calculates required steps per hour to reach goal
    // Based on remaining time and steps needed
    private var requiredStepsPerHour: Int {
        guard timeRemaining > 0 else { return 0 }
        let hoursRemaining = timeRemaining / 3600
        return Int(Double(stepsNeeded) / hoursRemaining)
    }
    
    // Layout combines:
    // - Enhanced progress bar
    // - Progress percentages
    // - Time remaining display
    // - Required pace information
    // - Motivational messages
    var body: some View {
        VStack(spacing: 8) {
            EnhancedProgressBar(
                progress: Double(currentSteps) / Double(goalSteps),
                expectedProgress: expectedProgress,
                startTime: startTime,
                endTime: endTime
            )
            .frame(height: 30)
            
            HStack {
                let percentComplete = (Double(currentSteps) / Double(goalSteps) * 100).rounded(to: 1)
                let expectedPercent = (expectedProgress * 100).rounded(to: 1)
                
                Text(String(format: "%.1f%% done ✅", percentComplete))
                    .fontWeight(.bold)
                    .foregroundColor(isAheadOfSchedule ? .green : .orange)
                if !isAheadOfSchedule {
                    let percentDiff = (expectedProgress - Double(currentSteps) / Double(goalSteps)) * 100
                    let percentBehind = percentDiff.rounded(to: 1)
                    Text(String(format: "(%.1f%% behind)", percentBehind))
                        .foregroundColor(.secondary)
                }
                Text("vs")
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%% target 🎯", expectedPercent))
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .font(.subheadline)
            
            HStack {
                Text("Time Remaining:")
                    .foregroundColor(.secondary)
                Text(formattedTimeRemaining)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(timeRemaining <= 0 ? .red : .primary)
                    .animation(.none, value: timeRemaining)
            }
            .padding(.top, 4)
            
            if timeRemaining > 0 && stepsNeeded > 0 {
                HStack {
                    Text("Required Pace:")
                        .foregroundColor(.secondary)
                    Text("\(requiredStepsPerHour) steps/hr")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                }
            }
            
            if !motivationalMessage.isEmpty {
                Text(motivationalMessage)
                    .font(.headline)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
        }
        .onAppear {
            // Start the timer when view appears
            timerCancellable = timer
                .autoconnect()
                .sink { _ in
                    currentTime = Date()
                }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
}

// Enhanced progress bar that shows:
// - Current progress
// - Expected progress marker
// - Start and end times
// - Visual indicators of progress status
struct EnhancedProgressBar: View {
    let progress: Double
    let expectedProgress: Double
    let startTime: Date
    let endTime: Date
    
    private var isAheadOfSchedule: Bool {
        progress >= expectedProgress
    }
    
    private var progressColor: Color {
        isAheadOfSchedule ? .green : .orange
    }
    
    private var progressBackgroundColor: Color {
        isAheadOfSchedule ? .green.opacity(0.3) : .orange.opacity(0.2)
    }
    
    private var formattedTime: (start: String, end: String) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return (
            start: formatter.string(from: startTime),
            end: formatter.string(from: endTime)
        )
    }
    
    private var shouldShowEndTime: Bool {
        let now = Date()
        return now < endTime || progress >= 1.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                
                // Progress bar
                Rectangle()
                    .foregroundColor(progressBackgroundColor)
                    .frame(width: min(geometry.size.width * progress, geometry.size.width))
                
                // Expected progress line (only show if before end time)
                if Date() < endTime {
                    Rectangle()
                        .foregroundColor(.blue)
                        .frame(width: 2)
                        .offset(x: geometry.size.width * expectedProgress - 1)
                }
                
                // Walker icon
                Image(systemName: "figure.walk")
                    .foregroundColor(progressColor)
                    .offset(x: min(geometry.size.width * progress - 10, geometry.size.width - 20))
            }
            .cornerRadius(10)
            .overlay(
                HStack {
                    Text(formattedTime.start)
                        .font(.caption)
                    Spacer()
                    if shouldShowEndTime {
                        Text(formattedTime.end)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 8)
            )
        }
    }
}

// Displays different pace options to reach goal:
// - Lists each pace option with details
// - Shows relative intensity of each option
// - Indicates time required for each pace
private struct PaceOptionsSection: View {
    let paceOptions: [PaceOption]
    
    private var maxTimeNeeded: TimeInterval {
        paceOptions.map { $0.timeNeeded }.max() ?? 1
    }
    
    private var maxStepsPerHour: Int {
        paceOptions.map { $0.stepsPerHour }.max() ?? 1
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Ways to Reach Your Goal")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            
            ForEach(paceOptions, id: \.name) { option in
                PaceOptionCard(
                    option: option,
                    timeProgress: option.timeNeeded / maxTimeNeeded,
                    intensityProgress: Double(option.stepsPerHour) / Double(maxStepsPerHour)
                )
            }
        }
    }
}

// Individual card showing pace option details:
// - Pace name and icon
// - Steps per hour required
// - Time needed to complete
// - Visual indicators for intensity and time
private struct PaceOptionCard: View {
    let option: PaceOption
    let timeProgress: Double
    let intensityProgress: Double
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Header with icon and pace name
            HStack(spacing: 10) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Text(option.icon)
                        .font(.system(size: 20))
                }
                
                // Name and steps/hour on same line
                HStack(spacing: 4) {
                    Text(option.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    
                    Text("\(option.stepsPerHour) steps/hr")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Time pill
                Text(PaceCalculator.formatTime(option.timeNeeded))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
            }
            
            // Progress indicators with labels above
            VStack(spacing: 1) {
                // Labels row
                HStack {
                    Text("Effort Level")
                        .font(.caption2)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text("Time Required")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                // Progress bars row
                HStack(spacing: 8) {
                    // Intensity bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                                .frame(height: 2)
                            
                            Capsule()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * intensityProgress, height: 2)
                        }
                    }
                    
                    // Time bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 3)
                            
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * timeProgress, height: 3)
                        }
                    }
                }
                .frame(height: 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackgroundColor)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 4,
                    x: 0,
                    y: 1
                )
        )
    }
}

// Basic progress bar component:
// - Shows simple filled bar
// - Used as base for EnhancedProgressBar
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                
                Rectangle()
                    .foregroundColor(.blue)
                    .frame(width: min(geometry.size.width * progress, geometry.size.width))
            }
            .cornerRadius(10)
        }
    }
}

// Animated celebration view shown when goal is reached:
// - Displays animated fireworks
// - Shows floating crown emoji
// - Creates visual reward for achievement
private struct CelebrationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Fireworks
            ForEach(0..<8) { index in
                FireworkView(angle: Double(index) * 45)
                    .opacity(isAnimating ? 0 : 1)
                    .scaleEffect(isAnimating ? 2 : 0.5)
            }
            
            // Crown
            Text("👑")
                .font(.system(size: 100))
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// Individual firework component:
// - Positions sparkle emoji at calculated angle
// - Part of CelebrationView animation
private struct FireworkView: View {
    let angle: Double
    
    var body: some View {
        Text("✨")
            .rotationEffect(.degrees(angle))
            .offset(
                x: CGFloat(cos(angle * .pi / 180)) * 50,
                y: CGFloat(sin(angle * .pi / 180)) * 50
            )
    }
} 
