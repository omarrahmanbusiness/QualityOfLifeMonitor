//
//  ScreenTimeManager.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import Foundation
import UIKit
import os

/// Screen Time Manager that tracks device usage without FamilyControls
/// Uses UIApplication lifecycle notifications to detect unlocks and app usage
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    private var publisher: ScreenTimePublisher?
    private var lastUnlockTime: Date?
    private var dailyPickupCount: Int32 = 0
    private var currentSessionStart: Date?

    @Published var isAuthorized: Bool = true // Always authorized (no special entitlement needed)

    private init() {
        setupNotifications()
    }

    func configure(publisher: ScreenTimePublisher) {
        self.publisher = publisher
    }

    // MARK: - Notifications Setup

    private func setupNotifications() {
        let notificationCenter = NotificationCenter.default

        // App became active (device unlocked or app foregrounded)
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // App will resign active (device locked or app backgrounded)
        notificationCenter.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // App entered background
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // App will terminate
        notificationCenter.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // Protected data became available (device was unlocked)
        notificationCenter.addObserver(
            self,
            selector: #selector(protectedDataDidBecomeAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc private func appDidBecomeActive() {
        let now = Date()
        currentSessionStart = now

        // Check if this is a new unlock (not just app switch)
        if lastUnlockTime == nil || now.timeIntervalSince(lastUnlockTime!) > 60 {
            // Record pickup
            dailyPickupCount += 1
            lastUnlockTime = now

            publisher?.publishPickup(date: now, unlockTime: now)

            AppLog.screenTime.debug("Device pickup recorded at \(now)")
        }
    }

    @objc private func appWillResignActive() {
        recordSessionDuration()
    }

    @objc private func appDidEnterBackground() {
        recordSessionDuration()
        saveDailySummary()
    }

    @objc private func appWillTerminate() {
        recordSessionDuration()
        saveDailySummary()
    }

    @objc private func protectedDataDidBecomeAvailable() {
        // Device was unlocked
        let now = Date()

        // Only count as pickup if significant time has passed
        if lastUnlockTime == nil || now.timeIntervalSince(lastUnlockTime!) > 300 {
            dailyPickupCount += 1
            lastUnlockTime = now

            publisher?.publishPickup(date: now, unlockTime: now)

            AppLog.screenTime.info("Device unlocked - pickup recorded")
            FileLogger.shared.log("Device unlocked - pickup recorded")
        }
    }

    // MARK: - Session Tracking

    private func recordSessionDuration() {
        guard let sessionStart = currentSessionStart else { return }

        let sessionDuration = Date().timeIntervalSince(sessionStart)

        // Only record sessions longer than 1 second
        if sessionDuration > 1 {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "QualityOfLifeMonitor"

            publisher?.publishAppUsage(
                date: sessionStart,
                appBundleId: bundleId,
                appName: appName,
                category: "Health & Fitness",
                duration: sessionDuration
            )

            AppLog.screenTime.debug("Session recorded: \(sessionDuration)s")
        }

        currentSessionStart = nil
    }

    private func saveDailySummary() {
        let today = Calendar.current.startOfDay(for: Date())

        // Get total duration for today from stored app usage
        let todayUsage = CoreDataManager.shared.fetchScreenTimeData(ofType: "appUsage", limit: 1000)
            .filter { entity in
                guard let date = entity.date else { return false }
                return Calendar.current.isDate(date, inSameDayAs: today)
            }
            .reduce(0.0) { $0 + $1.duration }

        publisher?.publishDailySummary(
            date: today,
            totalScreenTime: todayUsage,
            numberOfPickups: dailyPickupCount,
            firstUnlock: lastUnlockTime
        )
    }

    // MARK: - Start Monitoring

    func start() {
        // Reset daily counters at start
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Load existing pickup count for today
        let existingPickups = CoreDataManager.shared.fetchScreenTimeData(ofType: "pickup", limit: 1000)
            .filter { entity in
                guard let date = entity.date else { return false }
                return calendar.isDate(date, inSameDayAs: today)
            }
            .count

        dailyPickupCount = Int32(existingPickups)

        // Initialize category usage records for today
        initializeCategoryRecords(for: today)

        AppLog.screenTime.info("Screen Time monitoring started (without FamilyControls)")
        FileLogger.shared.log("Screen Time monitoring started (without FamilyControls)")
    }

    private func initializeCategoryRecords(for date: Date) {
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

        for category in categories {
            publisher?.publishCategoryUsage(
                date: date,
                category: category,
                duration: 0
            )
        }
    }

    // MARK: - Manual Recording

    /// Call this to manually record screen time data (for future FamilyControls integration)
    func recordScreenTime(totalMinutes: Double, pickups: Int32, for date: Date) {
        publisher?.publishDailySummary(
            date: date,
            totalScreenTime: totalMinutes * 60,
            numberOfPickups: pickups,
            firstUnlock: nil
        )
    }

    /// Record category usage manually
    func recordCategoryUsage(category: String, minutes: Double, for date: Date) {
        publisher?.publishCategoryUsage(
            date: date,
            category: category,
            duration: minutes * 60
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Logging Extension
extension AppLog {
    static let screenTime = Logger(subsystem: "com.yourcompany.QualityOfLifeMonitor", category: "screenTime")
}
