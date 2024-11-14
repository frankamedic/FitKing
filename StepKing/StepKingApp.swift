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
        
        // Start HealthKit observer
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                HealthKitManager.shared.startStepObserver()
            }
        }
        
        return true
    }
}
