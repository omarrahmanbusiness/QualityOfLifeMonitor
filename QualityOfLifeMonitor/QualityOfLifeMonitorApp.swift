//
//  QualityOfLifeMonitorApp.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 06/11/2025.
//

import SwiftUI

@main
struct QualityOfLifeMonitorApp: App {
    // Hold strong references so they live for the app lifetime
    private let locationPublisher = LocationPublisher()
    private lazy var locationManager = LocationManager(locationPublisher: locationPublisher)

    // HealthKit components
    private let healthKitPublisher = HealthKitPublisher()
    private let healthKitManager = HealthKitManager.shared

    init() {
        // Start background location monitoring early in app lifecycle
        locationManager.start()

        // Configure and start HealthKit monitoring
        healthKitManager.configure(publisher: healthKitPublisher)
        healthKitManager.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
