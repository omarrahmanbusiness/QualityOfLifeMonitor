//
//  AuthManager.swift
//  QualityOfLifeMonitor
//
//  Created on 23/11/2025.
//

import Foundation
import Combine

/// Manages user authentication with Supabase
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - Published State
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Configuration
    private let supabaseURL = Config.supabaseURL
    private let supabaseAnonKey = Config.supabaseAnonKey

    // UserDefaults keys
    private let accessTokenKey = "supabaseAccessToken"
    private let refreshTokenKey = "supabaseRefreshToken"
    private let userIdKey = "supabaseUserId"
    private let userEmailKey = "supabaseUserEmail"
    private let tokenExpiryKey = "supabaseTokenExpiry"

    // MARK: - Models
    struct User {
        let id: String
        let email: String
    }

    struct AuthResponse: Codable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: UserData

        struct UserData: Codable {
            let id: String
            let email: String?
        }
    }

    struct SignUpResponse: Codable {
        let id: String?
        let user: AuthResponse.UserData?
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
    }

    struct AuthError: Codable {
        let error: String?
        let error_description: String?
        let msg: String?
        let message: String?
    }

    private init() {
        loadStoredSession()
    }

    // MARK: - Session Management

    /// Load stored session from UserDefaults
    private func loadStoredSession() {
        guard let userId = UserDefaults.standard.string(forKey: userIdKey),
              let email = UserDefaults.standard.string(forKey: userEmailKey),
              let _ = UserDefaults.standard.string(forKey: accessTokenKey) else {
            isAuthenticated = false
            return
        }

        // Check if token is expired
        if let expiry = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date,
           expiry < Date() {
            // Token expired, try to refresh
            Task {
                do {
                    try await refreshSession()
                } catch {
                    await MainActor.run {
                        self.clearSession()
                    }
                }
            }
            return
        }

        currentUser = User(id: userId, email: email)
        isAuthenticated = true
    }

    /// Store session to UserDefaults
    private func storeSession(accessToken: String, refreshToken: String, expiresIn: Int, user: User) {
        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))

        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(user.id, forKey: userIdKey)
        UserDefaults.standard.set(user.email, forKey: userEmailKey)
        UserDefaults.standard.set(expiry, forKey: tokenExpiryKey)

        currentUser = user
        isAuthenticated = true
    }

    /// Clear stored session
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)

        currentUser = nil
        isAuthenticated = false
    }

    /// Get current access token
    var accessToken: String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }

    /// Get current user ID
    var userId: String? {
        UserDefaults.standard.string(forKey: userIdKey)
    }

    // MARK: - Authentication Methods

    /// Validate an invite code
    func validateInviteCode(_ code: String) async throws -> Bool {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/validate_invite_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["p_code": code]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthManagerError.invalidInviteCode
        }

        // Response is a boolean value
        if let result = try? JSONDecoder().decode(Bool.self, from: data) {
            return result
        }

        return false
    }

    /// Use an invite code (increment usage counter)
    private func useInviteCode(_ code: String) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/use_invite_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["p_code": code]
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Sign up a new user
    func signUp(email: String, password: String, inviteCode: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // First validate the invite code
        let isValid = try await validateInviteCode(inviteCode)
        guard isValid else {
            throw AuthManagerError.invalidInviteCode
        }

        // Sign up with Supabase Auth
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthManagerError.networkError
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                let message = errorResponse.error_description ?? errorResponse.msg ?? errorResponse.message ?? "Sign up failed"
                throw AuthManagerError.serverError(message)
            }
            throw AuthManagerError.serverError("Sign up failed with status \(httpResponse.statusCode)")
        }

        // Try to decode the response - handle both email confirmation enabled/disabled cases
        let decoder = JSONDecoder()

        // First try full auth response (email confirmation disabled)
        if let authResponse = try? decoder.decode(AuthResponse.self, from: data),
           let accessToken = authResponse.access_token,
           let refreshToken = authResponse.refresh_token,
           let expiresIn = authResponse.expires_in {

            // Use the invite code
            try await useInviteCode(inviteCode)

            // Create patient record linked to this user
            try await createPatientRecord(
                userId: authResponse.user.id,
                email: email,
                accessToken: accessToken
            )

            // Store session
            let user = User(id: authResponse.user.id, email: email)
            await MainActor.run {
                storeSession(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: expiresIn,
                    user: user
                )
            }
            return
        }

        // Try sign up response (email confirmation enabled - user needs to verify)
        if let signUpData = try? decoder.decode(SignUpResponse.self, from: data) {
            let userId = signUpData.id ?? signUpData.user?.id

            if let userId = userId {
                // Use the invite code
                try await useInviteCode(inviteCode)

                // If we have tokens, user is auto-confirmed
                if let accessToken = signUpData.access_token,
                   let refreshToken = signUpData.refresh_token,
                   let expiresIn = signUpData.expires_in {

                    try await createPatientRecord(
                        userId: userId,
                        email: email,
                        accessToken: accessToken
                    )

                    let user = User(id: userId, email: email)
                    await MainActor.run {
                        storeSession(
                            accessToken: accessToken,
                            refreshToken: refreshToken,
                            expiresIn: expiresIn,
                            user: user
                        )
                    }
                } else {
                    // Email confirmation required
                    throw AuthManagerError.serverError("Please check your email to confirm your account, then sign in.")
                }
                return
            }
        }

        throw AuthManagerError.serverError("Unexpected response from server")
    }

    /// Sign in an existing user
    func signIn(email: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthManagerError.networkError
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                let message = errorResponse.error_description ?? errorResponse.msg ?? errorResponse.message ?? "Sign in failed"
                throw AuthManagerError.serverError(message)
            }
            throw AuthManagerError.serverError("Sign in failed with status \(httpResponse.statusCode)")
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        guard let accessToken = authResponse.access_token,
              let refreshToken = authResponse.refresh_token,
              let expiresIn = authResponse.expires_in else {
            throw AuthManagerError.serverError("Invalid sign in response")
        }

        // Store session
        let user = User(id: authResponse.user.id, email: authResponse.user.email ?? email)
        await MainActor.run {
            storeSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn,
                user: user
            )
        }
    }

    /// Sign out the current user
    func signOut(deleteLocalData: Bool = false) async {
        await MainActor.run {
            isLoading = true
        }

        // Stop background tasks
        stopBackgroundTasks()

        // Optionally delete local data
        if deleteLocalData {
            deleteAllLocalData()
        }

        // Sign out from Supabase
        if let token = accessToken {
            let url = URL(string: "\(supabaseURL)/auth/v1/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            _ = try? await URLSession.shared.data(for: request)
        }

        await MainActor.run {
            clearSession()
            // Clear sync manager state
            clearSyncState()
            isLoading = false
        }
    }

    /// Refresh the access token
    func refreshSession() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            throw AuthManagerError.noRefreshToken
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            await MainActor.run {
                clearSession()
            }
            throw AuthManagerError.sessionExpired
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        guard let accessToken = authResponse.access_token,
              let newRefreshToken = authResponse.refresh_token,
              let expiresIn = authResponse.expires_in else {
            throw AuthManagerError.serverError("Invalid refresh response")
        }

        let user = User(
            id: authResponse.user.id,
            email: authResponse.user.email ?? currentUser?.email ?? ""
        )

        await MainActor.run {
            storeSession(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                expiresIn: expiresIn,
                user: user
            )
        }
    }

    // MARK: - Patient Record

    /// Create a patient record for the new user
    private func createPatientRecord(userId: String, email: String, accessToken: String) async throws {
        let deviceId = getDeviceId()

        let url = URL(string: "\(supabaseURL)/rest/v1/patients")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let patientData: [String: Any] = [
            "device_id": deviceId,
            "user_id": userId,
            "email": email
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: patientData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // Patient might already exist, try to update
            try await updatePatientRecord(userId: userId, email: email, deviceId: deviceId, accessToken: accessToken)
            return
        }

        // Cache patient ID
        if let patients = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let patient = patients.first,
           let patientId = patient["id"] as? String {
            UserDefaults.standard.set(patientId, forKey: "supabasePatientId")
        }
    }

    /// Update existing patient record with user_id
    private func updatePatientRecord(userId: String, email: String, deviceId: String, accessToken: String) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/patients?device_id=eq.\(deviceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateData: [String: String] = [
            "user_id": userId,
            "email": email
        ]
        request.httpBody = try JSONEncoder().encode(updateData)

        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Helpers

    private func getDeviceId() -> String {
        let key = "deviceUniqueId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private func stopBackgroundTasks() {
        // Cancel any scheduled background tasks
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SupabaseSyncManager.syncTaskIdentifier)

        // Stop monitoring services
        // Note: MonitoringServices is defined in QualityOfLifeMonitorApp.swift
        // We access it dynamically to avoid circular dependencies
        NotificationCenter.default.post(name: NSNotification.Name("StopMonitoringServices"), object: nil)

        FileLogger.shared.log("Background sync tasks cancelled for sign out")
    }

    private func deleteAllLocalData() {
        // Delete CoreData
        let context = CoreDataManager.shared.context

        // Delete all entities
        let entityNames = ["HealthSampleEntity", "LocationEntity", "ScreenTimeEntity", "HeartFailureEventEntity"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                FileLogger.shared.log("Failed to delete \(entityName): \(error.localizedDescription)")
            }
        }

        try? context.save()

        // Clear UserDefaults related to location categorization
        UserDefaults.standard.removeObject(forKey: "userHomeLocation")
        UserDefaults.standard.removeObject(forKey: "userWorkLocation")

        FileLogger.shared.log("All local data deleted for sign out")
    }

    private func clearSyncState() {
        UserDefaults.standard.removeObject(forKey: "lastSupabaseSyncDate")
        UserDefaults.standard.removeObject(forKey: "supabasePatientId")
    }

    // MARK: - Errors

    enum AuthManagerError: Error, LocalizedError {
        case invalidInviteCode
        case networkError
        case serverError(String)
        case noRefreshToken
        case sessionExpired

        var errorDescription: String? {
            switch self {
            case .invalidInviteCode:
                return "Invalid or expired invite code"
            case .networkError:
                return "Network error. Please check your connection."
            case .serverError(let message):
                return message
            case .noRefreshToken:
                return "No refresh token available"
            case .sessionExpired:
                return "Session expired. Please sign in again."
            }
        }
    }
}

import BackgroundTasks
import CoreData
