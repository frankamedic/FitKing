import Foundation
import Combine

class WeeklyFitnessViewModel: ObservableObject {
    @Published var weeklyData: [WeeklyFitnessData] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var selectedMetric: FitnessMetricType = .weight
    
    func loadWeeklyData(for metric: FitnessMetricType, settings: TrackingSettings) {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        HealthKitManager.shared.getWeeklyFitnessData(for: metric, settings: settings) { [weak self] data, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.weeklyData = []
                } else {
                    self?.weeklyData = data
                    self?.error = nil
                }
            }
        }
    }
    
    func refreshData(for metric: FitnessMetricType, settings: TrackingSettings) {
        // Force refresh by clearing current data
        weeklyData = []
        loadWeeklyData(for: metric, settings: settings)
    }
} 