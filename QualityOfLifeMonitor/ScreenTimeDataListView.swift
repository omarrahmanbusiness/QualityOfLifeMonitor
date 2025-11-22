//
//  ScreenTimeDataListView.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import SwiftUI
import CoreData

struct ScreenTimeDataListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: ScreenTimeFilter = .all
    @State private var screenTimeData: [ScreenTimeEntity] = []

    enum ScreenTimeFilter: String, CaseIterable {
        case all = "All"
        case dailySummary = "Daily Summary"
        case categoryUsage = "Categories"
        case appUsage = "Apps"
        case pickup = "Pickups"
    }

    var body: some View {
        VStack {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ScreenTimeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Data count
            Text("\(filteredData.count) records")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Data list
            List {
                ForEach(filteredData, id: \.id) { item in
                    ScreenTimeRow(item: item)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Screen Time")
        .onAppear {
            loadData()
        }
        .onChange(of: selectedFilter) { _, _ in
            loadData()
        }
    }

    private var filteredData: [ScreenTimeEntity] {
        switch selectedFilter {
        case .all:
            return screenTimeData
        case .dailySummary:
            return screenTimeData.filter { $0.metricType == "dailySummary" }
        case .categoryUsage:
            return screenTimeData.filter { $0.metricType == "categoryUsage" }
        case .appUsage:
            return screenTimeData.filter { $0.metricType == "appUsage" }
        case .pickup:
            return screenTimeData.filter { $0.metricType == "pickup" }
        }
    }

    private func loadData() {
        screenTimeData = CoreDataManager.shared.fetchAllScreenTimeData()
    }
}

struct ScreenTimeRow: View {
    let item: ScreenTimeEntity

    var body: some View {
        HStack {
            // Icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(.headline)

                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Date
                if let date = item.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Value
            Text(valueText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.metricType {
        case "dailySummary":
            return "clock.fill"
        case "categoryUsage":
            return "square.grid.2x2.fill"
        case "appUsage":
            return "app.fill"
        case "pickup":
            return "iphone"
        default:
            return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch item.metricType {
        case "dailySummary":
            return .blue
        case "categoryUsage":
            return .purple
        case "appUsage":
            return .green
        case "pickup":
            return .orange
        default:
            return .gray
        }
    }

    private var title: String {
        switch item.metricType {
        case "dailySummary":
            return "Daily Summary"
        case "categoryUsage":
            return item.category ?? "Unknown Category"
        case "appUsage":
            return item.appName ?? item.appBundleId ?? "Unknown App"
        case "pickup":
            return "Device Pickup"
        default:
            return item.metricType ?? "Unknown"
        }
    }

    private var subtitle: String? {
        switch item.metricType {
        case "dailySummary":
            return "\(item.numberOfPickups) pickups"
        case "categoryUsage":
            return nil
        case "appUsage":
            return item.category
        case "pickup":
            if let date = item.date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
            return nil
        default:
            return nil
        }
    }

    private var valueText: String {
        switch item.metricType {
        case "dailySummary":
            return formatDuration(item.totalScreenTime)
        case "categoryUsage", "appUsage":
            return formatDuration(item.duration)
        case "pickup":
            return ""
        default:
            return ""
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
}

#Preview {
    NavigationStack {
        ScreenTimeDataListView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
