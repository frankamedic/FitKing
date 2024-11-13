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
            VStack(spacing: 20) {
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
                            stepsNeeded: stepsNeeded
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
            
            ProgressBar(
                progress: Double(currentSteps) / Double(goalSteps)
            )
            .frame(height: 20)
            
            Text("Goal: \(goalSteps) steps")
                .foregroundColor(.secondary)
        }
    }
}

private struct TimeSection: View {
    let endTime: Date
    let stepsNeeded: Int
    
    private var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }
    
    private var minStepsPerHour: Int {
        let hoursRemaining = max(Date().distance(to: endTime) / 3600.0, 1.0)
        return Int(ceil(Double(stepsNeeded) / hoursRemaining))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Time Remaining")
                .font(.headline)
            
            if stepsNeeded > 0 {
                HStack {
                    Text("Min. Steps/Hour:")
                        .foregroundColor(.secondary)
                    Text("\(minStepsPerHour)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Goal deadline:")
                        .foregroundColor(.secondary)
                    Text(formattedEndTime)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Steps needed:")
                        .foregroundColor(.secondary)
                    Text("\(stepsNeeded)")
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
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
