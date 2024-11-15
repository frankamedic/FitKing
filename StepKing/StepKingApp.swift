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
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
                HealthKitManager.shared.startStepObserver()
                
                // Schedule initial background tasks
                let settings = TrackingSettings.load()
                if settings.isWithinTrackingPeriod() {
                    NotificationManager.shared.scheduleBackgroundRefresh(force: true)
                }
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Ensure background tasks are scheduled when app enters background
        NotificationManager.shared.handleAppStateChange(to: .background)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clean up and reschedule tasks when app becomes active
        NotificationManager.shared.handleAppStateChange(to: .active)
    }
}
