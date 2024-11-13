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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("App became active")
                viewModel.startTracking()
            case .inactive, .background:
                print("App entering background")
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
