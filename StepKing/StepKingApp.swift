//
//  StepKingApp.swift
//  StepKing
//
//  Created by Frank Sloan on 11/13/24.
//

import SwiftUI
import BackgroundTasks

@main
struct StepKingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("Scene phase changed from: \(oldPhase) to: \(newPhase)")
            switch newPhase {
            case .active:
                print("App became active")
                NotificationManager.shared.handleAppStateChange(.active)
            case .background:
                print("App entering background")
                NotificationManager.shared.handleAppStateChange(.background)
            case .inactive:
                print("App becoming inactive")
                NotificationManager.shared.handleAppStateChange(.inactive)
            @unknown default:
                break
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification authorization
        NotificationManager.shared.requestAuthorization()
        
        // Register background tasks
        NotificationManager.shared.registerBackgroundTasks()
        
        // Start HealthKit observer with proper error handling
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                HealthKitManager.shared.startStepObserver {
                    // Handle completion if needed
                }
                
                // Schedule initial background tasks
                let settings = TrackingSettings.load()
                if settings.isWithinTrackingPeriod() {
                    NotificationManager.shared.scheduleBackgroundRefresh()
                }
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
        
        return true
    }
}
