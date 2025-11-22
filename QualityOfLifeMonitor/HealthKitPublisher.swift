//
//  HealthKitPublisher.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import HealthKit
import CoreData
import os

class HealthKitPublisher {

    private let context: NSManagedObjectContext

    init() {
        self.context = CoreDataManager.shared.context
    }

    // MARK: - Publish Quantity Samples

    func publish(quantitySamples: [HKQuantitySample]) {
        guard !quantitySamples.isEmpty else { return }

        context.perform { [weak self] in
            guard let self = self else { return }

            for sample in quantitySamples {
                // Check if this sample already exists (by UUID)
                if self.sampleExists(uuid: sample.uuid) {
                    continue
                }

                let entity = HealthSampleEntity(context: self.context)
                entity.id = sample.uuid
                entity.sampleType = sample.quantityType.identifier
                entity.startDate = sample.startDate
                entity.endDate = sample.endDate
                entity.sourceName = sample.sourceRevision.source.name
                entity.sourceBundleId = sample.sourceRevision.source.bundleIdentifier

                // Get value and unit
                let (value, unit) = self.extractValueAndUnit(from: sample)
                entity.value = value
                entity.unit = unit
            }

            CoreDataManager.shared.save()
            AppLog.health.debug("Saved \(quantitySamples.count) quantity samples to Core Data")
        }
    }

    // MARK: - Publish Category Samples

    func publish(categorySamples: [HKCategorySample]) {
        guard !categorySamples.isEmpty else { return }

        context.perform { [weak self] in
            guard let self = self else { return }

            for sample in categorySamples {
                // Check if this sample already exists (by UUID)
                if self.sampleExists(uuid: sample.uuid) {
                    continue
                }

                let entity = HealthSampleEntity(context: self.context)
                entity.id = sample.uuid
                entity.sampleType = sample.categoryType.identifier
                entity.startDate = sample.startDate
                entity.endDate = sample.endDate
                entity.sourceName = sample.sourceRevision.source.name
                entity.sourceBundleId = sample.sourceRevision.source.bundleIdentifier
                entity.value = Double(sample.value)
                entity.unit = "category"
            }

            CoreDataManager.shared.save()
            AppLog.health.debug("Saved \(categorySamples.count) category samples to Core Data")
        }
    }

    // MARK: - Helper Methods

    /// Check if a sample with this UUID already exists
    private func sampleExists(uuid: UUID) -> Bool {
        let request: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }

    /// Extract the appropriate value and unit from a quantity sample
    private func extractValueAndUnit(from sample: HKQuantitySample) -> (Double, String) {
        let quantityType = sample.quantityType

        // Heart Rate and related
        if quantityType.is(compatibleWith: HKUnit.count().unitDivided(by: .minute())) {
            return (sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())), "count/min")
        }

        // Heart Rate Variability
        if quantityType.is(compatibleWith: HKUnit.secondUnit(with: .milli)) {
            return (sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)), "ms")
        }

        // Percentage (SpO2, body fat, etc.)
        if quantityType.is(compatibleWith: HKUnit.percent()) {
            return (sample.quantity.doubleValue(for: HKUnit.percent()) * 100, "%")
        }

        // Distance
        if quantityType.is(compatibleWith: HKUnit.meter()) {
            return (sample.quantity.doubleValue(for: HKUnit.meter()), "m")
        }

        // Energy
        if quantityType.is(compatibleWith: HKUnit.kilocalorie()) {
            return (sample.quantity.doubleValue(for: HKUnit.kilocalorie()), "kcal")
        }

        // Mass
        if quantityType.is(compatibleWith: HKUnit.gramUnit(with: .kilo)) {
            return (sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)), "kg")
        }

        // Count (steps, flights, etc.)
        if quantityType.is(compatibleWith: HKUnit.count()) {
            return (sample.quantity.doubleValue(for: HKUnit.count()), "count")
        }

        // Time/Duration
        if quantityType.is(compatibleWith: HKUnit.minute()) {
            return (sample.quantity.doubleValue(for: HKUnit.minute()), "min")
        }

        if quantityType.is(compatibleWith: HKUnit.second()) {
            return (sample.quantity.doubleValue(for: HKUnit.second()), "s")
        }

        // Pressure (blood pressure)
        if quantityType.is(compatibleWith: HKUnit.millimeterOfMercury()) {
            return (sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()), "mmHg")
        }

        // Temperature
        if quantityType.is(compatibleWith: HKUnit.degreeCelsius()) {
            return (sample.quantity.doubleValue(for: HKUnit.degreeCelsius()), "°C")
        }

        // Blood glucose
        if quantityType.is(compatibleWith: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))) {
            return (sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))), "mg/dL")
        }

        // Volume (water, etc.)
        if quantityType.is(compatibleWith: HKUnit.literUnit(with: .milli)) {
            return (sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli)), "mL")
        }

        // Speed
        if quantityType.is(compatibleWith: HKUnit.meter().unitDivided(by: .second())) {
            return (sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second())), "m/s")
        }

        // Sound level (dB)
        if quantityType.is(compatibleWith: HKUnit.decibelAWeightedSoundPressureLevel()) {
            return (sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel()), "dB")
        }

        // VO2 Max
        if quantityType.is(compatibleWith: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))) {
            return (sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))), "mL/kg/min")
        }

        // Default: try count
        if quantityType.is(compatibleWith: HKUnit.count()) {
            return (sample.quantity.doubleValue(for: HKUnit.count()), "count")
        }

        // Fallback
        return (0, "unknown")
    }
}

// MARK: - CoreDataManager Extension for Health Data
extension CoreDataManager {
    func fetchAllHealthSamples() -> [HealthSampleEntity] {
        let request: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            AppLog.health.error("Failed to fetch health samples: \(error.localizedDescription, privacy: .public)")
            FileLogger.shared.log("Failed to fetch health samples: \(error.localizedDescription)")
            return []
        }
    }

    func fetchHealthSamples(ofType sampleType: String, limit: Int = 100) -> [HealthSampleEntity] {
        let request: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "sampleType == %@", sampleType)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        request.fetchLimit = limit
        do {
            return try context.fetch(request)
        } catch {
            AppLog.health.error("Failed to fetch health samples: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchRecentHealthSamples(limit: Int) -> [HealthSampleEntity] {
        let request: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        request.fetchLimit = limit
        do {
            return try context.fetch(request)
        } catch {
            AppLog.health.error("Failed to fetch health samples: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func getHealthSampleCount() -> Int {
        let request: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }

    func getDistinctSampleTypes() -> [String] {
        let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "HealthSampleEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["sampleType"]
        request.returnsDistinctResults = true

        do {
            let results = try context.fetch(request)
            return results.compactMap { $0["sampleType"] as? String }
        } catch {
            return []
        }
    }
}
