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
        let identifier = sample.quantityType.identifier

        // Map identifiers to their correct units
        switch identifier {
        // Count-based metrics
        case HKQuantityTypeIdentifier.stepCount.rawValue,
             HKQuantityTypeIdentifier.flightsClimbed.rawValue,
             HKQuantityTypeIdentifier.pushCount.rawValue,
             HKQuantityTypeIdentifier.swimmingStrokeCount.rawValue,
             HKQuantityTypeIdentifier.numberOfTimesFallen.rawValue,
             HKQuantityTypeIdentifier.inhalerUsage.rawValue,
             HKQuantityTypeIdentifier.nikeFuel.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.count()), "count")

        // Heart rate (count/min)
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue,
             HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue,
             HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())), "bpm")

        // HRV (milliseconds)
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)), "ms")

        // Percentage-based metrics
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue,
             HKQuantityTypeIdentifier.bodyFatPercentage.rawValue,
             HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue,
             HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue,
             HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue,
             HKQuantityTypeIdentifier.bloodAlcoholContent.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.percent()) * 100, "%")

        // Distance (meters)
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
             HKQuantityTypeIdentifier.distanceCycling.rawValue,
             HKQuantityTypeIdentifier.distanceSwimming.rawValue,
             HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue,
             HKQuantityTypeIdentifier.walkingStepLength.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.meter()), "m")

        // Energy (kcal)
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.kilocalorie()), "kcal")

        // Time (minutes)
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
             HKQuantityTypeIdentifier.appleStandTime.rawValue,
             HKQuantityTypeIdentifier.appleMoveTime.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.minute()), "min")

        // Mass (kg)
        case HKQuantityTypeIdentifier.bodyMass.rawValue,
             HKQuantityTypeIdentifier.leanBodyMass.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)), "kg")

        // Height/length (cm)
        case HKQuantityTypeIdentifier.height.rawValue,
             HKQuantityTypeIdentifier.waistCircumference.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi)), "cm")

        // BMI (dimensionless)
        case HKQuantityTypeIdentifier.bodyMassIndex.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.count()), "")

        // Blood pressure (mmHg)
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()), "mmHg")

        // Temperature (°C)
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.degreeCelsius()), "°C")

        // Blood glucose (mg/dL)
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))), "mg/dL")

        // Sound (dB)
        case HKQuantityTypeIdentifier.environmentalAudioExposure.rawValue,
             HKQuantityTypeIdentifier.headphoneAudioExposure.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel()), "dB")

        // Speed (m/s)
        case HKQuantityTypeIdentifier.walkingSpeed.rawValue,
             HKQuantityTypeIdentifier.stairAscentSpeed.rawValue,
             HKQuantityTypeIdentifier.stairDescentSpeed.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second())), "m/s")

        // VO2 Max
        case HKQuantityTypeIdentifier.vo2Max.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))), "mL/kg/min")

        // Nutrition (grams)
        case HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue,
             HKQuantityTypeIdentifier.dietaryFatTotal.rawValue,
             HKQuantityTypeIdentifier.dietaryProtein.rawValue,
             HKQuantityTypeIdentifier.dietarySugar.rawValue,
             HKQuantityTypeIdentifier.dietaryFiber.rawValue,
             HKQuantityTypeIdentifier.dietaryCholesterol.rawValue,
             HKQuantityTypeIdentifier.dietarySodium.rawValue,
             HKQuantityTypeIdentifier.dietaryCaffeine.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.gram()), "g")

        // Volume (mL)
        case HKQuantityTypeIdentifier.dietaryWater.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli)), "mL")

        // Respiratory
        case HKQuantityTypeIdentifier.peakExpiratoryFlowRate.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.liter().unitDivided(by: .minute())), "L/min")

        case HKQuantityTypeIdentifier.forcedVitalCapacity.rawValue,
             HKQuantityTypeIdentifier.forcedExpiratoryVolume1.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.liter()), "L")

        // UV
        case HKQuantityTypeIdentifier.uvExposure.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.count()), "UV Index")

        // Electrodermal
        case HKQuantityTypeIdentifier.electrodermalActivity.rawValue:
            return (sample.quantity.doubleValue(for: HKUnit.siemen()), "µS")

        default:
            // Fallback: try common units
            if sample.quantityType.is(compatibleWith: HKUnit.count()) {
                return (sample.quantity.doubleValue(for: HKUnit.count()), "count")
            }
            return (0, "unknown")
        }
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
