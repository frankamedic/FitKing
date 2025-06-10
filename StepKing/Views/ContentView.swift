import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StepKingViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showToast = false
    @State private var toastMessage: String?
    
    var body: some View {
        ZStack {
            TabView {
                ProgressView(viewModel: viewModel)
                    .tabItem {
                        Label("Progress", systemImage: "figure.walk")
                    }
                
                WeeklyStepsView(mainViewModel: viewModel)
                    .tabItem {
                        Label("Weekly", systemImage: "calendar")
                    }
                
                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .onAppear {
                setupHealthKit()
                setupNotifications()
            }
            
            // Toast overlay
            if let message = toastMessage, showToast {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                        }
                }
                .padding(.bottom, 100)
            }
        }
        // TODO: Add light mode support (and themes) - for now, dark mode only (also in Info.plist)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("Scene phase changed from: \(oldPhase) to: \(newPhase)")
            switch newPhase {
            case .active:
                print("App became active")
                viewModel.startTracking()
            case .background:
                print("App entering background")
                viewModel.stopTracking()
            case .inactive:
                print("App becoming inactive")
                viewModel.stopTracking()
            @unknown default:
                break
            }
        }
    }
    
    private func setupHealthKit() {
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                viewModel.startTracking()
            }
        }
    }
    
    private func setupNotifications() {
        NotificationManager.shared.requestAuthorization()
    }
} 
