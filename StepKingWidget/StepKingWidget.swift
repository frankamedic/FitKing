import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    private let groupID = "group.com.sloaninnovation.StepKing"
    
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
        let steps = UserDefaults(suiteName: groupID)?.integer(forKey: "currentSteps") ?? 0
        let entry = StepEntry(date: Date(), steps: steps)
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
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