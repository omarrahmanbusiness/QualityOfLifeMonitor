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
        // Register background sync task (always register, but only schedule when authenticated)
        SupabaseSyncManager.shared.registerBackgroundTask()

        // Only schedule sync if user is authenticated
        if AuthManager.shared.isAuthenticated {
            SupabaseSyncManager.shared.scheduleNextSync()
        }
        return true
    }
}

@main
struct QualityOfLifeMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared

    init() {
        // Start monitoring services if already authenticated
        if AuthManager.shared.isAuthenticated {
            MonitoringServices.shared.startIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Parse the URL fragment for access_token
        // URL format: qualityoflifemonitor://reset-password#access_token=...&type=recovery
        guard let fragment = url.fragment else { return }

        // Parse fragment parameters
        let params = fragment.components(separatedBy: "&")
            .map { $0.components(separatedBy: "=") }
            .filter { $0.count == 2 }
            .reduce(into: [String: String]()) { dict, pair in
                dict[pair[0]] = pair[1]
            }

        // Check if this is a recovery token
        if let accessToken = params["access_token"],
           params["type"] == "recovery" {
            authManager.pendingRecoveryToken = accessToken
        }
    }
}

/// Root view that switches between Auth and Main content
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .onAppear {
                        // Start services and schedule sync when user authenticates
                        MonitoringServices.shared.startIfNeeded()
                        SupabaseSyncManager.shared.scheduleNextSync()
                    }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

/// Singleton to manage monitoring services lifecycle
final class MonitoringServices {
    static let shared = MonitoringServices()

    private var isStarted = false
    private let locationPublisher = LocationPublisher()
    private lazy var locationManager = LocationManager(locationPublisher: locationPublisher)
    private let healthKitPublisher = HealthKitPublisher()
    private let healthKitManager = HealthKitManager.shared
    private let screenTimePublisher = ScreenTimePublisher()

    private init() {}

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true

        // Start background location monitoring
        locationManager.start()

        // Configure and start HealthKit monitoring
        healthKitManager.configure(publisher: healthKitPublisher)
        healthKitManager.start()

        // Configure Screen Time monitoring (iOS 15+)
        if #available(iOS 15.0, *) {
            ScreenTimeManager.shared.configure(publisher: screenTimePublisher)
        }

        FileLogger.shared.log("Monitoring services started")
    }

    func stop() {
        isStarted = false
        // Location and HealthKit managers will be cleaned up when user signs out
        FileLogger.shared.log("Monitoring services stopped")
    }
}
