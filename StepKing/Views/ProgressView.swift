import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Steps Today")
                .font(.title)
            
            Text("\(currentSteps)")
                .font(.system(size: 48, weight: .bold))
            
            Text("Goal: \(goalSteps) steps")
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }
}

private struct TimeSection: View {
    let endTime: Date
    let stepsNeeded: Int
    let currentSteps: Int
    let goalSteps: Int
    @ObservedObject var viewModel: StepKingViewModel
    
    // Add timer state
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        let seconds = Int(timeRemaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
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
                let percentComplete = Int((Double(currentSteps) / Double(goalSteps) * 100))
                let expectedPercent = Int(expectedProgress * 100)
                
                Text("\(percentComplete)% completed")
                    .fontWeight(.bold)
                    .foregroundColor(isAheadOfSchedule ? .green : .orange)
                if !isAheadOfSchedule {
                    let percentBehind = max(1, expectedPercent - percentComplete)
                    Text("(\(percentBehind)% behind)")
                        .foregroundColor(.secondary)
                }
                Text("vs")
                    .foregroundColor(.secondary)
                Text("\(expectedPercent)% expected")
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
            }
            .padding(.top, 4)
            
            if !motivationalMessage.isEmpty {
                Text(motivationalMessage)
                    .font(.headline)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
            // ... rest of the existing TimeSection content ...
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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Ways to Reach Your Goal")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(paceOptions, id: \.name) { option in
                VStack(spacing: 8) {
                    // Top row with icon and pace
                    HStack {
                        Text(option.icon)
                            .font(.title)
                            .frame(width: 40, alignment: .center)
                        
                        Text("Pace:")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(option.name)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Steps per hour row
                    HStack {
                        // Empty space for icon alignment
                        Color.clear
                            .frame(width: 40)
                        
                        Text("Steps/hour:")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text("\(option.stepsPerHour)")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Total time row
                    HStack {
                        // Empty space for icon alignment
                        Color.clear
                            .frame(width: 40)
                        
                        Text("Total Time:")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(PaceCalculator.formatTime(option.timeNeeded))
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
            }
        }
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
