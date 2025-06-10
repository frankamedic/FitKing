import Foundation
import Combine

class WeeklyStepsViewModel: ObservableObject {
    @Published var weeklyData: [WeeklyStepData] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let healthKitManager = HealthKitManager.shared
    
    func loadWeeklyData(goalSteps: Int) {
        isLoading = true
        error = nil
        
        healthKitManager.getWeeklyStepData(goalSteps: goalSteps) { [weak self] data, error in
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
    
    func refreshData(goalSteps: Int) {
        loadWeeklyData(goalSteps: goalSteps)
    }
} 