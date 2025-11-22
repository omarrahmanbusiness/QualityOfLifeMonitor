//
//  ScreenTimeManager.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import os

@available(iOS 15.0, *)
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    private let center = AuthorizationCenter.shared
    private var publisher: ScreenTimePublisher?

    @Published var isAuthorized: Bool = false

    private init() {
        checkAuthorizationStatus()
    }

    func configure(publisher: ScreenTimePublisher) {
        self.publisher = publisher
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        isAuthorized = center.authorizationStatus == .approved
    }

    func requestAuthorization() async -> Bool {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                isAuthorized = center.authorizationStatus == .approved
            }
            AppLog.screenTime.info("Screen Time authorization granted")
            FileLogger.shared.log("Screen Time authorization granted")
            return true
        } catch {
            AppLog.screenTime.error("Screen Time authorization failed: \(error.localizedDescription, privacy: .public)")
            FileLogger.shared.log("Screen Time authorization failed: \(error.localizedDescription)")
            await MainActor.run {
                isAuthorized = false
            }
            return false
        }
    }

    // MARK: - Data Collection

    /// Start monitoring screen time data
    func start() {
        guard isAuthorized else {
            AppLog.screenTime.warning("Screen Time not authorized - skipping monitoring")
            FileLogger.shared.log("Screen Time not authorized - skipping monitoring")
            return
        }

        // Fetch historical data
        fetchScreenTimeData()

        // Set up device activity monitoring
        setupDeviceActivityMonitoring()

        AppLog.screenTime.info("Screen Time monitoring started")
        FileLogger.shared.log("Screen Time monitoring started")
    }

    /// Fetch screen time data and publish to CoreData
    func fetchScreenTimeData() {
        guard isAuthorized else { return }

        // Collect daily summary data for the past 30 days
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else { return }

        // Create daily records for tracking
        var currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

            // Create a daily summary record
            // Note: DeviceActivityReport provides detailed data, but we store aggregated summaries
            publisher?.publishDailySummary(
                date: dayStart,
                totalScreenTime: 0, // Will be updated by DeviceActivityReport
                numberOfPickups: 0,
                firstUnlock: nil
            )

            currentDate = dayEnd
        }

        AppLog.screenTime.info("Initialized screen time data records for past 30 days")
    }

    /// Set up device activity monitoring schedule
    private func setupDeviceActivityMonitoring() {
        let center = DeviceActivityCenter()

        // Create a schedule for monitoring
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(
                .daily,
                during: schedule
            )
            AppLog.screenTime.info("Device activity monitoring started")
        } catch {
            AppLog.screenTime.error("Failed to start device activity monitoring: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch app category usage breakdown
    func fetchCategoryUsage(for date: Date) {
        guard isAuthorized else { return }

        // Categories we track
        let categories = [
            "Social",
            "Entertainment",
            "Productivity",
            "Games",
            "Education",
            "Health & Fitness",
            "News",
            "Shopping",
            "Travel",
            "Utilities",
            "Other"
        ]

        // Create category records (actual data comes from DeviceActivityReport)
        for category in categories {
            publisher?.publishCategoryUsage(
                date: date,
                category: category,
                duration: 0 // Will be populated by DeviceActivityReport
            )
        }
    }
}

// MARK: - Device Activity Name Extension
extension DeviceActivityName {
    static let daily = Self("daily")
}

// MARK: - Logging Extension
extension AppLog {
    static let screenTime = Logger(subsystem: "com.yourcompany.QualityOfLifeMonitor", category: "screenTime")
}
