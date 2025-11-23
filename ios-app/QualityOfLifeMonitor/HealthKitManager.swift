//
//  HealthKitManager.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import HealthKit
import os

class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var publisher: HealthKitPublisher?

    // MARK: - Health Data Types to Read

    /// All quantity types we want to read from HealthKit
    static let quantityTypes: Set<HKQuantityType> = {
        var types = Set<HKQuantityType>()

        // Vital Signs
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) { types.insert(type) }

        // Activity
        if let type = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .distanceCycling) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .nikeFuel) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .pushCount) { types.insert(type) }

        // Body Measurements
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .height) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .waistCircumference) { types.insert(type) }

        // Nutrition
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietarySugar) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietarySodium) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) { types.insert(type) }

        // Respiratory
        if let type = HKQuantityType.quantityType(forIdentifier: .peakExpiratoryFlowRate) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .forcedVitalCapacity) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .forcedExpiratoryVolume1) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .inhalerUsage) { types.insert(type) }

        // Blood Glucose & Lab Results
        if let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .bloodAlcoholContent) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .electrodermalActivity) { types.insert(type) }

        // Mobility
        if let type = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) { types.insert(type) }

        // Hearing
        if let type = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) { types.insert(type) }

        // UV Exposure
        if let type = HKQuantityType.quantityType(forIdentifier: .uvExposure) { types.insert(type) }

        // Heart-related (iOS 14+)
        if let type = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) { types.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) { types.insert(type) }

        // Mindfulness
        if let type = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) { types.insert(type) }

        return types
    }()

    /// Category types we want to read from HealthKit
    static let categoryTypes: Set<HKCategoryType> = {
        var types = Set<HKCategoryType>()

        // Sleep
        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(type) }

        // Mindfulness
        if let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) { types.insert(type) }

        // Reproductive Health
        if let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .ovulationTestResult) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .sexualActivity) { types.insert(type) }

        // Symptoms
        if let type = HKCategoryType.categoryType(forIdentifier: .lowHeartRateEvent) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .highHeartRateEvent) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .irregularHeartRhythmEvent) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .audioExposureEvent) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .toothbrushingEvent) { types.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .handwashingEvent) { types.insert(type) }

        // Activity
        if let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) { types.insert(type) }

        return types
    }()

    /// All types to read (quantity + category)
    static var allTypesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        types.formUnion(quantityTypes)
        types.formUnion(categoryTypes)
        return types
    }

    // MARK: - Initialization

    private init() {}

    func configure(publisher: HealthKitPublisher) {
        self.publisher = publisher
    }

    // MARK: - Authorization

    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for all health data types
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthKitAvailable else {
            AppLog.health.error("HealthKit is not available on this device")
            FileLogger.shared.log("HealthKit is not available on this device")
            completion(false, nil)
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: Self.allTypesToRead) { success, error in
            if let error = error {
                AppLog.health.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
                FileLogger.shared.log("HealthKit authorization failed: \(error.localizedDescription)")
            } else if success {
                AppLog.health.info("HealthKit authorization granted")
                FileLogger.shared.log("HealthKit authorization granted")
            }
            completion(success, error)
        }
    }

    /// Get authorization status for a specific type
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }

    // MARK: - Data Queries

    /// Fetch historical data for all types
    func fetchAllHistoricalData(from startDate: Date, to endDate: Date = Date()) {
        AppLog.health.info("Fetching historical health data from \(startDate) to \(endDate)")
        FileLogger.shared.log("Fetching historical health data from \(startDate) to \(endDate)")

        // Fetch quantity samples
        for quantityType in Self.quantityTypes {
            fetchQuantitySamples(for: quantityType, from: startDate, to: endDate)
        }

        // Fetch category samples
        for categoryType in Self.categoryTypes {
            fetchCategorySamples(for: categoryType, from: startDate, to: endDate)
        }
    }

    /// Fetch quantity samples for a specific type
    private func fetchQuantitySamples(for quantityType: HKQuantityType, from startDate: Date, to endDate: Date) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                AppLog.health.error("Failed to fetch \(quantityType.identifier): \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let quantitySamples = samples as? [HKQuantitySample] else { return }

            AppLog.health.debug("Fetched \(quantitySamples.count) samples for \(quantityType.identifier)")

            self?.publisher?.publish(quantitySamples: quantitySamples)
        }

        healthStore.execute(query)
    }

    /// Fetch category samples for a specific type
    private func fetchCategorySamples(for categoryType: HKCategoryType, from startDate: Date, to endDate: Date) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: categoryType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                AppLog.health.error("Failed to fetch \(categoryType.identifier): \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let categorySamples = samples as? [HKCategorySample] else { return }

            AppLog.health.debug("Fetched \(categorySamples.count) samples for \(categoryType.identifier)")

            self?.publisher?.publish(categorySamples: categorySamples)
        }

        healthStore.execute(query)
    }

    // MARK: - Background Delivery

    /// Enable background delivery for all supported types
    func enableBackgroundDelivery() {
        guard isHealthKitAvailable else { return }

        for quantityType in Self.quantityTypes {
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
                if let error = error {
                    AppLog.health.error("Failed to enable background delivery for \(quantityType.identifier): \(error.localizedDescription, privacy: .public)")
                } else if success {
                    AppLog.health.debug("Background delivery enabled for \(quantityType.identifier)")
                }
            }
        }

        for categoryType in Self.categoryTypes {
            healthStore.enableBackgroundDelivery(for: categoryType, frequency: .immediate) { success, error in
                if let error = error {
                    AppLog.health.error("Failed to enable background delivery for \(categoryType.identifier): \(error.localizedDescription, privacy: .public)")
                } else if success {
                    AppLog.health.debug("Background delivery enabled for \(categoryType.identifier)")
                }
            }
        }
    }

    /// Set up observer queries for real-time updates
    func setupObserverQueries() {
        guard isHealthKitAvailable else { return }

        for quantityType in Self.quantityTypes {
            setupObserverQuery(for: quantityType)
        }

        for categoryType in Self.categoryTypes {
            setupObserverQuery(for: categoryType)
        }

        AppLog.health.info("Observer queries set up for all health types")
        FileLogger.shared.log("Observer queries set up for all health types")
    }

    private func setupObserverQuery(for sampleType: HKSampleType) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                AppLog.health.error("Observer query error for \(sampleType.identifier): \(error.localizedDescription, privacy: .public)")
                completionHandler()
                return
            }

            // Fetch the new data
            self?.fetchRecentSamples(for: sampleType)
            completionHandler()
        }

        healthStore.execute(query)
    }

    /// Fetch recent samples (last hour) for a specific type
    private func fetchRecentSamples(for sampleType: HKSampleType) {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: 100,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                AppLog.health.error("Failed to fetch recent \(sampleType.identifier): \(error.localizedDescription, privacy: .public)")
                return
            }

            if let quantitySamples = samples as? [HKQuantitySample] {
                self?.publisher?.publish(quantitySamples: quantitySamples)
            } else if let categorySamples = samples as? [HKCategorySample] {
                self?.publisher?.publish(categorySamples: categorySamples)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Start Monitoring

    /// Start the health monitoring service
    func start() {
        guard isHealthKitAvailable else {
            AppLog.health.warning("HealthKit not available - skipping health monitoring")
            FileLogger.shared.log("HealthKit not available - skipping health monitoring")
            return
        }

        requestAuthorization { [weak self] success, error in
            guard success else { return }

            // Fetch last 30 days of data
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            self?.fetchAllHistoricalData(from: thirtyDaysAgo)

            // Enable background delivery
            self?.enableBackgroundDelivery()

            // Set up observer queries for new data
            self?.setupObserverQueries()
        }
    }
}

// MARK: - Logging Extension
extension AppLog {
    static let health = Logger(subsystem: "com.yourcompany.QualityOfLifeMonitor", category: "health")
}
