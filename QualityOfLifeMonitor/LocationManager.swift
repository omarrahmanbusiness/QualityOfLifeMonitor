//
//  LocationManager.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 08/11/2025.
//

import CoreLocation
import os

class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let locationPublisher: LocationPublisher

    init(locationPublisher: LocationPublisher) {
        self.locationPublisher = locationPublisher
        super.init()
        locationManager.delegate = self
        // Reasonable defaults for background use
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // meters
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }

    func start() {
        // Request Always so background delivery is permitted
        locationManager.requestAlwaysAuthorization()

        // Enable background location updates; requires Background Modes capability
        locationManager.allowsBackgroundLocationUpdates = true

        // Start significant-change monitoring for efficiency
        locationManager.startMonitoringSignificantLocationChanges()

        AppLog.location.info("Location monitoring started (SLC).")
        FileLogger.shared.log("Location monitoring started (SLC).")

        // Optionally also start standard updates to improve frequency when app is active
        // locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        AppLog.location.info("Background update at: \(last.timestamp, privacy: .public)")
        AppLog.location.debug("Coords: \(last.coordinate.latitude, privacy: .public), \(last.coordinate.longitude, privacy: .public)")
        FileLogger.shared.log("Background update at: \(last.timestamp) Coords: \(last.coordinate.latitude), \(last.coordinate.longitude)")
        locationPublisher.publish(locations)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.startMonitoringSignificantLocationChanges()
            AppLog.location.notice("Authorization: Always")
            FileLogger.shared.log("Authorization: Always")
        case .authorizedWhenInUse:
            AppLog.location.info("Authorization: When In Use (background limited)")
            FileLogger.shared.log("Authorization: When In Use (background limited)")
        case .denied:
            AppLog.location.error("Authorization: Denied")
            FileLogger.shared.log("Authorization: Denied")
        case .restricted:
            AppLog.location.error("Authorization: Restricted")
            FileLogger.shared.log("Authorization: Restricted")
        case .notDetermined:
            AppLog.location.debug("Authorization: Not Determined")
            FileLogger.shared.log("Authorization: Not Determined")
        @unknown default:
            AppLog.location.error("Authorization: Unknown")
            FileLogger.shared.log("Authorization: Unknown")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLog.location.error("Location error: \(error.localizedDescription, privacy: .public)")
        FileLogger.shared.log("Location error: \(error.localizedDescription)")
    }
}
