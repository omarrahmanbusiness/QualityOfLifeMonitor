//
//  QualityOfLifeMonitorApp.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 06/11/2025.
//

import SwiftUI
import BackgroundTasks

// AppDelegate for background task registration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background sync task
        SupabaseSyncManager.shared.registerBackgroundTask()
        // Schedule after registration
        SupabaseSyncManager.shared.scheduleNextSync()
        return true
    }
}

@main
struct QualityOfLifeMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Hold strong references so they live for the app lifetime
    private let locationPublisher = LocationPublisher()
    private lazy var locationManager = LocationManager(locationPublisher: locationPublisher)

    // HealthKit components
    private let healthKitPublisher = HealthKitPublisher()
    private let healthKitManager = HealthKitManager.shared

    // Screen Time components
    private let screenTimePublisher = ScreenTimePublisher()

    init() {
        // Start background location monitoring early in app lifecycle
        locationManager.start()

        // Configure and start HealthKit monitoring
        healthKitManager.configure(publisher: healthKitPublisher)
        healthKitManager.start()

        // Configure Screen Time monitoring (iOS 15+)
        if #available(iOS 15.0, *) {
            ScreenTimeManager.shared.configure(publisher: screenTimePublisher)
            // Start will be called after authorization is granted in StatusViewModel
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
