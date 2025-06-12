//
//  FitKingApp.swift
//  FitKing
//
//  Created by Frank Sloan on 11/13/24.
//

import SwiftUI
import BackgroundTasks

@main
struct FitKingApp: App {
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
        
        // Register background tasks (this includes initial scheduling)
        NotificationManager.shared.registerBackgroundTasks()
        
        // Start HealthKit observer with proper error handling
        HealthKitManager.shared.requestAuthorization { success, error in
            if success {
                HealthKitManager.shared.startFitnessObserver {
                    // Handle completion if needed
                }
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("📱 App terminating - ensuring background refresh is scheduled")
        
        // Use dispatch semaphore to ensure scheduling completes
        let semaphore = DispatchSemaphore(value: 0)
        
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            if requests.isEmpty {
                print("📅 No background tasks found - scheduling new refresh")
                NotificationManager.shared.scheduleBackgroundRefresh()
            } else {
                print("✅ Background tasks already scheduled: \(requests.count)")
            }
            semaphore.signal()
        }
        
        // Wait for scheduling but with a shorter timeout
        _ = semaphore.wait(timeout: .now() + 0.25)
    }
}
