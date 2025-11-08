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

struct StatusView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = StatusViewModel()
    @State private var showRemedy = false

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
                    }
                }
                .listStyle(.insetGrouped)

                Spacer()
            }
            .navigationTitle("Status")
            .sheet(isPresented: $showRemedy) {
                RemedyView(onDone: { showRemedy = false })
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

@MainActor
final class StatusViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationSatisfied: Bool = false
    private var lastStatus: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    var overallStatusEmoji: String { locationSatisfied ? "✅" : "❌" }
    var overallStatusText: String { locationSatisfied ? "All set" : "Action required" }
    var locationStatusEmoji: String { locationSatisfied ? "✅" : "❌" }
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

    override init() {
        super.init()
        manager.delegate = self
        lastStatus = manager.authorizationStatus
        locationSatisfied = (lastStatus == .authorizedAlways)
    }

    func refresh() {
        let status = manager.authorizationStatus
        lastStatus = status
        locationSatisfied = (status == .authorizedAlways)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        lastStatus = status
        locationSatisfied = (status == .authorizedAlways)
    }
}

#Preview {
    ContentView()
}

