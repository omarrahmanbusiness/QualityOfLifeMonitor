//
//  ContentView.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 06/11/2025.
//

import SwiftUI
import UIKit
import Combine
import CoreLocation
import CoreData
import HealthKit
import FamilyControls

struct StatusView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = StatusViewModel()
    @State private var showRemedy = false
    @State private var showHealthRemedy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Overall status
                VStack(spacing: 8) {
                    Text(viewModel.overallStatusEmoji)
                        .font(.system(size: 72))
                        .accessibilityLabel(viewModel.overallStatusText)
                    Text(viewModel.overallStatusText)
                        .font(.headline)
                }
                .padding(.top, 24)

                // Prerequisites list
                List {
                    Section("Prerequisites") {
                        Button(action: {
                            if !viewModel.locationSatisfied {
                                showRemedy = true
                            }
                        }) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text("Location Access")
                                    Text(viewModel.locationStatusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(viewModel.locationStatusEmoji)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.locationSatisfied)

                        Button(action: {
                            if !viewModel.healthSatisfied {
                                showHealthRemedy = true
                            }
                        }) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text("Health Access")
                                    Text(viewModel.healthStatusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(viewModel.healthStatusEmoji)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.healthSatisfied)

                        Button(action: {
                            if !viewModel.screenTimeSatisfied {
                                viewModel.requestScreenTimeAuthorization()
                            }
                        }) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text("Screen Time Access")
                                    Text(viewModel.screenTimeStatusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(viewModel.screenTimeStatusEmoji)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.screenTimeSatisfied)
                    }
                }
                .listStyle(.insetGrouped)

                Spacer()
            }
            .navigationTitle("Status")
            .sheet(isPresented: $showRemedy) {
                RemedyView(onDone: { showRemedy = false })
            }
            .sheet(isPresented: $showHealthRemedy) {
                HealthRemedyView(onDone: { showHealthRemedy = false }, onRequest: {
                    viewModel.requestHealthAuthorization()
                })
            }
            .onAppear {
                viewModel.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.refresh()
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem {
                    Label("Prerequisites", systemImage: "checklist")
                }
            DataRootView()
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
                .tabItem {
                    Label("Data", systemImage: "tray.full")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showSignOutAlert = false
    @State private var deleteDataOnSignOut = false
    @State private var isSyncing = false
    @State private var syncMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.email ?? "Unknown")
                                .font(.headline)
                            Text("Patient ID: \(String(authManager.userId?.prefix(8) ?? "..."))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }

                // Sync Section
                Section("Data Sync") {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        if let lastSync = SupabaseSyncManager.shared.lastSyncDate {
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: syncNow) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Syncing...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                        }
                    }
                    .disabled(isSyncing)

                    if !syncMessage.isEmpty {
                        Text(syncMessage)
                            .font(.caption)
                            .foregroundColor(syncMessage.contains("Error") ? .red : .green)
                    }
                }

                // Account Section
                Section("Account") {
                    Button(role: .destructive, action: { showSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }

                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    signOut(deleteData: false)
                }
                Button("Sign Out & Delete Data", role: .destructive) {
                    signOut(deleteData: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Do you want to sign out? You can optionally delete all local data.")
            }
        }
    }

    private func syncNow() {
        isSyncing = true
        syncMessage = ""

        Task {
            do {
                try await SupabaseSyncManager.shared.syncNow()
                await MainActor.run {
                    syncMessage = "Sync completed successfully"
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    syncMessage = "Error: \(error.localizedDescription)"
                    isSyncing = false
                }
            }
        }
    }

    private func signOut(deleteData: Bool) {
        Task {
            await authManager.signOut(deleteLocalData: deleteData)
        }
    }
}

private struct RemedyView: View {
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Grant Full Location Access")
                        .font(.title2)
                        .bold()
                    Text("To enable background tracking, please grant \"Always\" location access:")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open the Settings app.")
                        Text("2. Tap \"Privacy & Security\" > \"Location Services\".")
                        Text("3. Find and select \"QualityOfLifeMonitor\".")
                        Text("4. Set \"Allow Location Access\" to \"Always\".")
                        Text("5. Ensure \"Precise Location\" is enabled for best accuracy (optional).")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Go to Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("How to Fix")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDone() } } }
        }
    }
}

private struct HealthRemedyView: View {
    var onDone: () -> Void
    var onRequest: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Grant Health Data Access")
                        .font(.title2)
                        .bold()
                    Text("To monitor your health metrics, please grant access to HealthKit data:")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Tap \"Request Access\" below to show the HealthKit permission dialog.")
                        Text("2. Review the health data types and tap \"Turn On All\" or select specific types.")
                        Text("3. Tap \"Allow\" to grant access.")
                        Text("")
                        Text("If you've already denied access:")
                        Text("1. Open the Settings app.")
                        Text("2. Tap \"Privacy & Security\" > \"Health\".")
                        Text("3. Find and select \"QualityOfLifeMonitor\".")
                        Text("4. Enable the data types you want to share.")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Button("Request Access") {
                            onRequest()
                            onDone()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Go to Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            onDone()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("How to Fix")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDone() } } }
        }
    }
}

@MainActor
final class StatusViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationSatisfied: Bool = false
    @Published var healthSatisfied: Bool = false
    @Published var screenTimeSatisfied: Bool = false
    private var lastStatus: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()
    private let healthStore = HKHealthStore()

    var overallStatusEmoji: String { (locationSatisfied && healthSatisfied && screenTimeSatisfied) ? "✅" : "❌" }
    var overallStatusText: String { (locationSatisfied && healthSatisfied && screenTimeSatisfied) ? "All set" : "Action required" }
    var locationStatusEmoji: String { locationSatisfied ? "✅" : "❌" }
    var healthStatusEmoji: String { healthSatisfied ? "✅" : "❌" }
    var screenTimeStatusEmoji: String { screenTimeSatisfied ? "✅" : "❌" }
    var locationStatusText: String {
        switch lastStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
    var healthStatusText: String {
        guard HKHealthStore.isHealthDataAvailable() else {
            return "Not Available"
        }
        return healthSatisfied ? "Authorized" : "Not Authorized"
    }
    var screenTimeStatusText: String {
        return screenTimeSatisfied ? "Authorized" : "Not Authorized"
    }

    override init() {
        super.init()
        manager.delegate = self
        lastStatus = manager.authorizationStatus
        locationSatisfied = (lastStatus == .authorizedAlways)
        if (!locationSatisfied) {
            manager.requestAlwaysAuthorization()
        }
        checkHealthAuthorization()

        // Auto-request health authorization if not yet determined
        if !healthSatisfied && HKHealthStore.isHealthDataAvailable() {
            requestHealthAuthorization()
        }

        // Check screen time authorization
        checkScreenTimeAuthorization()
    }

    func refresh() {
        let status = manager.authorizationStatus
        lastStatus = status
        locationSatisfied = (status == .authorizedAlways)
        checkHealthAuthorization()
        checkScreenTimeAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        lastStatus = status
        locationSatisfied = (status == .authorizedAlways)
    }

    func checkHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthSatisfied = false
            return
        }

        // For read-only access, we need to check request status since authorizationStatus
        // only works for write permissions
        healthStore.getRequestStatusForAuthorization(toShare: [], read: HealthKitManager.allTypesToRead) { [weak self] status, error in
            DispatchQueue.main.async {
                // If status is .unnecessary, authorization has already been determined
                self?.healthSatisfied = (status == .unnecessary)
            }
        }
    }

    func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        healthStore.requestAuthorization(toShare: nil, read: HealthKitManager.allTypesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.checkHealthAuthorization()
            }
        }
    }

    func checkScreenTimeAuthorization() {
        if #available(iOS 15.0, *) {
            screenTimeSatisfied = AuthorizationCenter.shared.authorizationStatus == .approved
        } else {
            screenTimeSatisfied = false
        }
    }

    func requestScreenTimeAuthorization() {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    await MainActor.run {
                        checkScreenTimeAuthorization()
                        if screenTimeSatisfied {
                            ScreenTimeManager.shared.start()
                        }
                    }
                } catch {
                    await MainActor.run {
                        screenTimeSatisfied = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

