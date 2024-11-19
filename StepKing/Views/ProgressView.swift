import SwiftUI

extension Double {
    func rounded(to decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}

struct ProgressView: View {
    @ObservedObject var viewModel: StepKingViewModel
    
    private var stepsNeeded: Int {
        max(0, viewModel.settings.dailyStepGoal - viewModel.currentSteps)
    }
    
    private var paceOptions: [PaceOption] {
        PaceCalculator.calculatePaceOptions(stepsNeeded: stepsNeeded)
    }
    
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

private struct ProgressSection: View {
    let currentSteps: Int
    let goalSteps: Int
    
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

private struct TimeSection: View {
    let endTime: Date
    let stepsNeeded: Int
    let currentSteps: Int
    let goalSteps: Int
    @ObservedObject var viewModel: StepKingViewModel
    
    // Update timer to match tenth of second display
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect() // 10fps
    
    private var startTime: Date {
        viewModel.settings.todayStartTime
    }
    
    private var timeRemaining: TimeInterval {
        currentTime.distance(to: endTime)
    }
    
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
    
    private var expectedProgress: Double {
        if timeRemaining <= 0 {
            return 1.0  // 100% expected when past end time
        }
        return viewModel.settings.expectedProgress()
    }
    
    private var isAheadOfSchedule: Bool {
        Double(currentSteps) / Double(goalSteps) >= expectedProgress
    }
    
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
    
    private var requiredStepsPerHour: Int {
        guard timeRemaining > 0 else { return 0 }
        let hoursRemaining = timeRemaining / 3600
        return Int(Double(stepsNeeded) / hoursRemaining)
    }
    
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
            
            // ... rest of the existing TimeSection content ...
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
    }
}

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
