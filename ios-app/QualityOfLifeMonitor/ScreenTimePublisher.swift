//
//  ScreenTimePublisher.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import Foundation
import CoreData
import os

class ScreenTimePublisher {

    private let context: NSManagedObjectContext

    init() {
        self.context = CoreDataManager.shared.context
    }

    // MARK: - Publish Daily Summary

    /// Publish daily screen time summary
    func publishDailySummary(date: Date, totalScreenTime: Double, numberOfPickups: Int32, firstUnlock: Date?) {
        context.perform { [weak self] in
            guard let self = self else { return }

            // Check if a summary for this date already exists
            if self.dailySummaryExists(for: date) {
                // Update existing record
                self.updateDailySummary(date: date, totalScreenTime: totalScreenTime, numberOfPickups: numberOfPickups)
                return
            }

            let entity = ScreenTimeEntity(context: self.context)
            entity.id = UUID()
            entity.date = date
            entity.metricType = "dailySummary"
            entity.totalScreenTime = totalScreenTime
            entity.numberOfPickups = numberOfPickups
            entity.duration = totalScreenTime
            entity.category = nil
            entity.appBundleId = nil
            entity.appName = nil

            CoreDataManager.shared.save()
            AppLog.screenTime.debug("Saved daily screen time summary for \(date)")
        }
    }

    /// Update existing daily summary
    private func updateDailySummary(date: Date, totalScreenTime: Double, numberOfPickups: Int32) {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND date >= %@ AND date < %@",
            "dailySummary",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                existing.totalScreenTime = totalScreenTime
                existing.numberOfPickups = numberOfPickups
                existing.duration = totalScreenTime
                CoreDataManager.shared.save()
            }
        } catch {
            AppLog.screenTime.error("Failed to update daily summary: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Publish Category Usage

    /// Publish app category usage data
    func publishCategoryUsage(date: Date, category: String, duration: Double) {
        context.perform { [weak self] in
            guard let self = self else { return }

            // Check if category usage for this date exists
            if self.categoryUsageExists(for: date, category: category) {
                self.updateCategoryUsage(date: date, category: category, duration: duration)
                return
            }

            let entity = ScreenTimeEntity(context: self.context)
            entity.id = UUID()
            entity.date = date
            entity.metricType = "categoryUsage"
            entity.category = category
            entity.duration = duration
            entity.totalScreenTime = 0
            entity.numberOfPickups = 0
            entity.appBundleId = nil
            entity.appName = nil

            CoreDataManager.shared.save()
            AppLog.screenTime.debug("Saved category usage for \(category) on \(date)")
        }
    }

    /// Update existing category usage
    private func updateCategoryUsage(date: Date, category: String, duration: Double) {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND category == %@ AND date >= %@ AND date < %@",
            "categoryUsage",
            category,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                existing.duration = duration
                CoreDataManager.shared.save()
            }
        } catch {
            AppLog.screenTime.error("Failed to update category usage: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Publish App Usage

    /// Publish individual app usage data
    func publishAppUsage(date: Date, appBundleId: String, appName: String, category: String, duration: Double) {
        context.perform { [weak self] in
            guard let self = self else { return }

            // Check if app usage for this date exists
            if self.appUsageExists(for: date, appBundleId: appBundleId) {
                self.updateAppUsage(date: date, appBundleId: appBundleId, duration: duration)
                return
            }

            let entity = ScreenTimeEntity(context: self.context)
            entity.id = UUID()
            entity.date = date
            entity.metricType = "appUsage"
            entity.appBundleId = appBundleId
            entity.appName = appName
            entity.category = category
            entity.duration = duration
            entity.totalScreenTime = 0
            entity.numberOfPickups = 0

            CoreDataManager.shared.save()
            AppLog.screenTime.debug("Saved app usage for \(appName) on \(date)")
        }
    }

    /// Update existing app usage
    private func updateAppUsage(date: Date, appBundleId: String, duration: Double) {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND appBundleId == %@ AND date >= %@ AND date < %@",
            "appUsage",
            appBundleId,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                existing.duration = duration
                CoreDataManager.shared.save()
            }
        } catch {
            AppLog.screenTime.error("Failed to update app usage: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Publish Pickup Data

    /// Publish pickup/unlock data
    func publishPickup(date: Date, unlockTime: Date) {
        context.perform { [weak self] in
            guard let self = self else { return }

            let entity = ScreenTimeEntity(context: self.context)
            entity.id = UUID()
            entity.date = unlockTime
            entity.metricType = "pickup"
            entity.duration = 0
            entity.totalScreenTime = 0
            entity.numberOfPickups = 1
            entity.category = nil
            entity.appBundleId = nil
            entity.appName = nil

            CoreDataManager.shared.save()
            AppLog.screenTime.debug("Saved pickup at \(unlockTime)")
        }
    }

    // MARK: - Helper Methods

    /// Check if daily summary exists for date
    private func dailySummaryExists(for date: Date) -> Bool {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND date >= %@ AND date < %@",
            "dailySummary",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            return try context.count(for: request) > 0
        } catch {
            return false
        }
    }

    /// Check if category usage exists for date and category
    private func categoryUsageExists(for date: Date, category: String) -> Bool {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND category == %@ AND date >= %@ AND date < %@",
            "categoryUsage",
            category,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            return try context.count(for: request) > 0
        } catch {
            return false
        }
    }

    /// Check if app usage exists for date and bundle ID
    private func appUsageExists(for date: Date, appBundleId: String) -> Bool {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND appBundleId == %@ AND date >= %@ AND date < %@",
            "appUsage",
            appBundleId,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            return try context.count(for: request) > 0
        } catch {
            return false
        }
    }
}

// MARK: - CoreDataManager Extension for Screen Time Data
extension CoreDataManager {
    func fetchAllScreenTimeData() -> [ScreenTimeEntity] {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            AppLog.screenTime.error("Failed to fetch screen time data: \(error.localizedDescription, privacy: .public)")
            FileLogger.shared.log("Failed to fetch screen time data: \(error.localizedDescription)")
            return []
        }
    }

    func fetchScreenTimeData(ofType metricType: String, limit: Int = 100) -> [ScreenTimeEntity] {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "metricType == %@", metricType)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        do {
            return try context.fetch(request)
        } catch {
            AppLog.screenTime.error("Failed to fetch screen time data: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchDailySummaries(limit: Int = 30) -> [ScreenTimeEntity] {
        return fetchScreenTimeData(ofType: "dailySummary", limit: limit)
    }

    func fetchCategoryUsage(for date: Date) -> [ScreenTimeEntity] {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        request.predicate = NSPredicate(
            format: "metricType == %@ AND date >= %@ AND date < %@",
            "categoryUsage",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    func getScreenTimeDataCount() -> Int {
        let request: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }

    func getDistinctMetricTypes() -> [String] {
        let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "ScreenTimeEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["metricType"]
        request.returnsDistinctResults = true

        do {
            let results = try context.fetch(request)
            return results.compactMap { $0["metricType"] as? String }
        } catch {
            return []
        }
    }
}
