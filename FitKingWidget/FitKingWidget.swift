import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    private let groupID = "group.com.sloaninnovation.StepKing"
    private let healthKitManager = HealthKitManager.shared
    
    func placeholder(in context: Context) -> StepEntry {
        StepEntry(date: Date(), steps: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: groupID)
        let steps = sharedDefaults?.integer(forKey: "currentSteps") ?? 0
        let entry = StepEntry(date: Date(), steps: steps)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Get settings from shared defaults
        let sharedDefaults = UserDefaults(suiteName: groupID)
        let settings = TrackingSettings.load()
        
        // Check if within tracking period
        guard settings.isWithinTrackingPeriod() else {
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [StepEntry(date: Date(), steps: 0)], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // Get current steps
        healthKitManager.getTodaySteps { steps, error in
            if let error = error {
                print("Error getting steps: \(error)")
                return
            }
            
            // Save steps to shared defaults
            sharedDefaults?.setValue(steps, forKey: "currentSteps")
            
            // Check if notification needed
            self.checkAndScheduleNotification(steps: steps, settings: settings)
            
            // Create timeline entry
            let entry = StepEntry(date: Date(), steps: steps)
            
            // Update more frequently when behind pace
            let updateInterval = self.shouldUpdateMoreFrequently(steps: steps, settings: settings) ? 5 : 15
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: updateInterval, to: Date())!
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func shouldUpdateMoreFrequently(steps: Int, settings: TrackingSettings) -> Bool {
        let expectedProgress = settings.expectedProgress()
        let expectedSteps = Int(Double(settings.dailyStepGoal) * expectedProgress)
        return steps < expectedSteps
    }
    
    private func checkAndScheduleNotification(steps: Int, settings: TrackingSettings) {
        let notificationManager = NotificationManager.shared
        notificationManager.scheduleStepProgressNotification(
            currentSteps: steps,
            goalSteps: settings.dailyStepGoal,
            endTime: settings.todayEndTime,
            date: Date()
        )
    }
}

struct StepEntry: TimelineEntry {
    let date: Date
    let steps: Int
}

struct StepKingWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            Text("Steps Today")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(entry.steps)")
                .font(.title2)
                .bold()
            
            Image(systemName: "figure.walk")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
}

@main
struct StepKingWidget: Widget {
    let kind: String = "StepKingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StepKingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Step Counter")
        .description("Shows your daily step count.")
        .supportedFamilies([.systemSmall])
    }
} 