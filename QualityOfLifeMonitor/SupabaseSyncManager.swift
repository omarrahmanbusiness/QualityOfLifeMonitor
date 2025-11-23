//
//  SupabaseSyncManager.swift
//  QualityOfLifeMonitor
//
//  Created on 22/11/2025.
//

import Foundation
import BackgroundTasks
import UIKit
import CoreData

/// Manages synchronization of local CoreData to Supabase
final class SupabaseSyncManager {
    static let shared = SupabaseSyncManager()

    // MARK: - Configuration
    private let supabaseURL = Config.supabaseURL
    private let supabaseAnonKey = Config.supabaseAnonKey

    // Background task identifier
    static let syncTaskIdentifier = "com.qualityoflifemonitor.dailysync"

    // UserDefaults keys for tracking sync state
    private let lastSyncDateKey = "lastSupabaseSyncDate"
    private let patientIdKey = "supabasePatientId"
    private let deviceIdKey = "deviceUniqueId"

    // Sync configuration
    private let maxRetryAttempts = 4
    private let initialRetryDelay: TimeInterval = 2.0

    private init() {}

    // MARK: - Device ID Management

    /// Get or create a unique device identifier
    private var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    /// Get cached patient ID from Supabase
    private var patientId: String? {
        get { UserDefaults.standard.string(forKey: patientIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: patientIdKey) }
    }

    /// Get last sync date
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncDateKey) }
    }

    // MARK: - Background Task Registration

    /// Register background task - call this in AppDelegate or App init
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }

    /// Schedule the next sync for early morning (4-5 AM)
    func scheduleNextSync() {
        let request = BGProcessingTaskRequest(identifier: Self.syncTaskIdentifier)

        // Calculate next 4 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 4
        dateComponents.minute = 0

        let calendar = Calendar.current
        var nextSyncDate: Date

        if let todayAt4AM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: Date()),
           todayAt4AM > Date() {
            nextSyncDate = todayAt4AM
        } else {
            // Schedule for tomorrow at 4 AM
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            nextSyncDate = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: tomorrow)!
        }

        request.earliestBeginDate = nextSyncDate
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false  // Allow sync on battery

        do {
            try BGTaskScheduler.shared.submit(request)
            FileLogger.shared.log("Scheduled next sync for \(nextSyncDate)")
        } catch {
            FileLogger.shared.log("Failed to schedule sync: \(error.localizedDescription)")
        }
    }

    /// Handle background sync task
    private func handleBackgroundSync(task: BGProcessingTask) {
        // Schedule next sync before starting current one
        scheduleNextSync()

        // Create a task to track expiration
        let syncTask = Task {
            do {
                try await performSync()
                task.setTaskCompleted(success: true)
            } catch {
                FileLogger.shared.log("Background sync failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            syncTask.cancel()
        }
    }

    // MARK: - Manual Sync

    /// Perform a manual sync (can be called from UI)
    func syncNow() async throws {
        try await performSync()
    }

    // MARK: - Core Sync Logic

    /// Main sync method with retry logic
    private func performSync() async throws {
        FileLogger.shared.log("Starting Supabase sync...")

        // Ensure patient exists in Supabase
        let patientId = try await ensurePatientExists()

        // Determine sync type
        let isInitialSync = lastSyncDate == nil
        let syncStartDate = Date()

        // Record sync start
        let syncHistoryId = try await recordSyncStart(
            patientId: patientId,
            syncType: isInitialSync ? "initial" : "incremental"
        )

        var totalRecords = 0
        var healthCount = 0
        var locationCount = 0
        var screenTimeCount = 0
        var hfEventCount = 0

        do {
            // Sync each entity type
            healthCount = try await syncHealthSamples(patientId: patientId)
            totalRecords += healthCount

            locationCount = try await syncLocations(patientId: patientId)
            totalRecords += locationCount

            screenTimeCount = try await syncScreenTime(patientId: patientId)
            totalRecords += screenTimeCount

            hfEventCount = try await syncHeartFailureEvents(patientId: patientId)
            totalRecords += hfEventCount

            // Update sync history
            try await recordSyncComplete(
                syncHistoryId: syncHistoryId,
                recordsSynced: totalRecords,
                healthCount: healthCount,
                locationCount: locationCount,
                screenTimeCount: screenTimeCount,
                hfEventCount: hfEventCount
            )

            // Update last sync date
            lastSyncDate = syncStartDate

            FileLogger.shared.log("Sync completed: \(totalRecords) records synced")

        } catch {
            // Record sync failure
            try? await recordSyncFailed(syncHistoryId: syncHistoryId, error: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Patient Management

    /// Ensure patient record exists in Supabase
    private func ensurePatientExists() async throws -> String {
        // Return cached patient ID if available
        if let existing = patientId {
            return existing
        }

        // Check if patient exists by device ID
        let checkURL = URL(string: "\(supabaseURL)/rest/v1/patients?device_id=eq.\(deviceId)&select=id")!
        var checkRequest = URLRequest(url: checkURL)
        addAuthHeaders(to: &checkRequest)
        checkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (checkData, _) = try await performRequestWithRetry(checkRequest)

        if let patients = try? JSONDecoder().decode([[String: String]].self, from: checkData),
           let existingPatient = patients.first,
           let id = existingPatient["id"] {
            patientId = id
            return id
        }

        // Create new patient
        let createURL = URL(string: "\(supabaseURL)/rest/v1/patients")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        addAuthHeaders(to: &createRequest)
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let patientData = ["device_id": deviceId]
        createRequest.httpBody = try JSONEncoder().encode(patientData)

        let (createData, _) = try await performRequestWithRetry(createRequest)

        guard let newPatients = try? JSONDecoder().decode([[String: String]].self, from: createData),
              let newPatient = newPatients.first,
              let id = newPatient["id"] else {
            throw SyncError.patientCreationFailed
        }

        patientId = id
        return id
    }

    // MARK: - Entity Sync Methods

    /// Sync health samples to Supabase
    private func syncHealthSamples(patientId: String) async throws -> Int {
        let context = CoreDataManager.shared.context

        let fetchRequest: NSFetchRequest<HealthSampleEntity> = HealthSampleEntity.fetchRequest()

        // For incremental sync, only fetch records since last sync
        if let lastSync = lastSyncDate {
            fetchRequest.predicate = NSPredicate(format: "startDate > %@", lastSync as NSDate)
        }

        let samples = try context.fetch(fetchRequest)

        guard !samples.isEmpty else { return 0 }

        // Convert to JSON-compatible format
        let records = samples.map { sample -> [String: Any] in
            [
                "id": sample.id?.uuidString ?? UUID().uuidString,
                "patient_id": patientId,
                "sample_type": sample.sampleType ?? "",
                "start_date": ISO8601DateFormatter().string(from: sample.startDate ?? Date()),
                "end_date": ISO8601DateFormatter().string(from: sample.endDate ?? Date()),
                "value": sample.value,
                "unit": sample.unit ?? "",
                "source_name": sample.sourceName ?? "",
                "source_bundle_id": sample.sourceBundleId ?? ""
            ]
        }

        try await upsertRecords(table: "health_samples", records: records)

        return samples.count
    }

    /// Sync locations to Supabase
    private func syncLocations(patientId: String) async throws -> Int {
        let context = CoreDataManager.shared.context

        let fetchRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()

        if let lastSync = lastSyncDate {
            fetchRequest.predicate = NSPredicate(format: "timestamp > %@", lastSync as NSDate)
        }

        let locations = try context.fetch(fetchRequest)

        guard !locations.isEmpty else { return 0 }

        let records = locations.map { location -> [String: Any] in
            var record: [String: Any] = [
                "patient_id": patientId,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "altitude": location.altitude,
                "speed": location.speed,
                "timestamp": ISO8601DateFormatter().string(from: location.timestamp ?? Date())
            ]

            if let address = location.address { record["address"] = address }
            if let placeName = location.placeName { record["place_name"] = placeName }
            if let category = location.category { record["category"] = category }

            return record
        }

        try await insertRecords(table: "locations", records: records, onConflict: "patient_id,timestamp,latitude,longitude")

        return locations.count
    }

    /// Sync screen time data to Supabase
    private func syncScreenTime(patientId: String) async throws -> Int {
        let context = CoreDataManager.shared.context

        let fetchRequest: NSFetchRequest<ScreenTimeEntity> = ScreenTimeEntity.fetchRequest()

        if let lastSync = lastSyncDate {
            fetchRequest.predicate = NSPredicate(format: "date > %@", lastSync as NSDate)
        }

        let screenTimeRecords = try context.fetch(fetchRequest)

        guard !screenTimeRecords.isEmpty else { return 0 }

        let records = screenTimeRecords.map { st -> [String: Any] in
            var record: [String: Any] = [
                "id": st.id?.uuidString ?? UUID().uuidString,
                "patient_id": patientId,
                "date": ISO8601DateFormatter().string(from: st.date ?? Date()),
                "metric_type": st.metricType ?? ""
            ]

            if st.totalScreenTime > 0 { record["total_screen_time"] = st.totalScreenTime }
            if st.numberOfPickups > 0 { record["number_of_pickups"] = st.numberOfPickups }
            if st.duration > 0 { record["duration"] = st.duration }
            if let bundleId = st.appBundleId { record["app_bundle_id"] = bundleId }
            if let appName = st.appName { record["app_name"] = appName }
            if let category = st.category { record["category"] = category }

            return record
        }

        try await upsertRecords(table: "screen_time", records: records)

        return screenTimeRecords.count
    }

    /// Sync heart failure events to Supabase
    private func syncHeartFailureEvents(patientId: String) async throws -> Int {
        let context = CoreDataManager.shared.context

        let fetchRequest: NSFetchRequest<HeartFailureEventEntity> = HeartFailureEventEntity.fetchRequest()

        if let lastSync = lastSyncDate {
            fetchRequest.predicate = NSPredicate(format: "timestamp > %@", lastSync as NSDate)
        }

        let events = try context.fetch(fetchRequest)

        guard !events.isEmpty else { return 0 }

        let records = events.map { event -> [String: Any] in
            var record: [String: Any] = [
                "id": event.id?.uuidString ?? UUID().uuidString,
                "patient_id": patientId,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp ?? Date())
            ]

            if let notes = event.notes { record["notes"] = notes }

            return record
        }

        try await upsertRecords(table: "heart_failure_events", records: records)

        return events.count
    }

    // MARK: - Sync History

    private func recordSyncStart(patientId: String, syncType: String) async throws -> String {
        let url = URL(string: "\(supabaseURL)/rest/v1/sync_history")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let syncRecord: [String: Any] = [
            "patient_id": patientId,
            "sync_type": syncType,
            "started_at": ISO8601DateFormatter().string(from: Date()),
            "status": "in_progress"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: syncRecord)

        let (data, _) = try await performRequestWithRetry(request)

        guard let response = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = response.first,
              let id = first["id"] as? String else {
            throw SyncError.syncHistoryCreationFailed
        }

        return id
    }

    private func recordSyncComplete(
        syncHistoryId: String,
        recordsSynced: Int,
        healthCount: Int,
        locationCount: Int,
        screenTimeCount: Int,
        hfEventCount: Int
    ) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/sync_history?id=eq.\(syncHistoryId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateRecord: [String: Any] = [
            "completed_at": ISO8601DateFormatter().string(from: Date()),
            "status": "completed",
            "records_synced": recordsSynced,
            "health_samples_count": healthCount,
            "locations_count": locationCount,
            "screen_time_count": screenTimeCount,
            "hf_events_count": hfEventCount
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: updateRecord)

        _ = try await performRequestWithRetry(request)
    }

    private func recordSyncFailed(syncHistoryId: String, error: String) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/sync_history?id=eq.\(syncHistoryId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateRecord: [String: Any] = [
            "completed_at": ISO8601DateFormatter().string(from: Date()),
            "status": "failed",
            "error_message": error
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: updateRecord)

        _ = try await performRequestWithRetry(request)
    }

    // MARK: - Network Helpers

    /// Get authorization header with access token if available
    private func addAuthHeaders(to request: inout URLRequest) {
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Insert records with conflict handling
    private func insertRecords(table: String, records: [[String: Any]], onConflict: String) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?on_conflict=\(onConflict)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")

        // Batch records in chunks of 1000
        let chunkSize = 1000
        for chunk in stride(from: 0, to: records.count, by: chunkSize) {
            let end = min(chunk + chunkSize, records.count)
            let batch = Array(records[chunk..<end])

            request.httpBody = try JSONSerialization.data(withJSONObject: batch)
            _ = try await performRequestWithRetry(request)
        }
    }

    /// Upsert records (insert or update)
    private func upsertRecords(table: String, records: [[String: Any]]) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        // Batch records in chunks of 1000
        let chunkSize = 1000
        for chunk in stride(from: 0, to: records.count, by: chunkSize) {
            let end = min(chunk + chunkSize, records.count)
            let batch = Array(records[chunk..<end])

            request.httpBody = try JSONSerialization.data(withJSONObject: batch)
            _ = try await performRequestWithRetry(request)
        }
    }

    /// Perform HTTP request with exponential backoff retry
    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<maxRetryAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw SyncError.httpError(statusCode: httpResponse.statusCode)
                }

                return (data, response)
            } catch {
                lastError = error

                // Don't retry on non-network errors
                if case SyncError.httpError(let code) = error, code != 500 && code != 502 && code != 503 {
                    throw error
                }

                // Exponential backoff: 2s, 4s, 8s, 16s
                if attempt < maxRetryAttempts - 1 {
                    let delay = initialRetryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    FileLogger.shared.log("Retry attempt \(attempt + 1) after \(delay)s delay")
                }
            }
        }

        throw lastError ?? SyncError.unknownError
    }

    // MARK: - Errors

    enum SyncError: Error, LocalizedError {
        case patientCreationFailed
        case syncHistoryCreationFailed
        case httpError(statusCode: Int)
        case unknownError

        var errorDescription: String? {
            switch self {
            case .patientCreationFailed:
                return "Failed to create patient record in Supabase"
            case .syncHistoryCreationFailed:
                return "Failed to create sync history record"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .unknownError:
                return "Unknown sync error"
            }
        }
    }
}
