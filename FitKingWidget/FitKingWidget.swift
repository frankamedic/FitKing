import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    private let groupID = "group.com.sloaninnovation.FitKing"
    private let healthKitManager = HealthKitManager.shared
    
    func placeholder(in context: Context) -> FitnessEntry {
        FitnessEntry(date: Date(), weight: 0, calories: 0, carbs: 0, protein: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (FitnessEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: groupID)
        let weight = sharedDefaults?.double(forKey: "currentWeight") ?? 0
        let calories = sharedDefaults?.double(forKey: "currentCalories") ?? 0
        let carbs = sharedDefaults?.double(forKey: "currentCarbs") ?? 0
        let protein = sharedDefaults?.double(forKey: "currentProtein") ?? 0
        let entry = FitnessEntry(date: Date(), weight: weight, calories: calories, carbs: carbs, protein: protein)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Get settings from shared defaults
        let sharedDefaults = UserDefaults(suiteName: groupID)
        let settings = TrackingSettings.load()
        
        // Check if within tracking period
        guard settings.isWithinTrackingPeriod() else {
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [FitnessEntry(date: Date(), weight: 0, calories: 0, carbs: 0, protein: 0)], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // Get current fitness data
        healthKitManager.getTodayFitnessData { fitnessData, error in
            if let error = error {
                print("Error getting fitness data: \(error)")
                return
            }
            
            // Save fitness data to shared defaults
            sharedDefaults?.setValue(fitnessData.weight, forKey: "currentWeight")
            sharedDefaults?.setValue(fitnessData.calories, forKey: "currentCalories")
            sharedDefaults?.setValue(fitnessData.carbs, forKey: "currentCarbs")
            sharedDefaults?.setValue(fitnessData.protein, forKey: "currentProtein")
            
            // Check if notification needed
            self.checkAndScheduleNotification(fitnessData: fitnessData, settings: settings)
            
            // Create timeline entry
            let entry = FitnessEntry(
                date: Date(), 
                weight: fitnessData.weight,
                calories: fitnessData.calories,
                carbs: fitnessData.carbs,
                protein: fitnessData.protein
            )
            
            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func checkAndScheduleNotification(fitnessData: DailyFitnessData, settings: TrackingSettings) {
        let notificationManager = NotificationManager.shared
        notificationManager.scheduleFitnessProgressNotification(
            fitnessData: fitnessData,
            settings: settings,
            date: Date()
        )
    }
}

struct FitnessEntry: TimelineEntry {
    let date: Date
    let weight: Double
    let calories: Double
    let carbs: Double
    let protein: Double
}

struct FitKingWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Fitness Today")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("\(Int(entry.calories))")
                        .font(.caption)
                        .bold()
                    Text("cal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(Int(entry.protein))")
                        .font(.caption)
                        .bold()
                    Text("protein")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

@main
struct FitKingWidget: Widget {
    let kind: String = "FitKingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FitKingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fitness Tracker")
        .description("Shows your daily fitness progress.")
        .supportedFamilies([.systemSmall])
    }
} 