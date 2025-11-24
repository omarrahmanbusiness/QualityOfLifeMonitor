//
//  HealthDataListView.swift
//  QualityOfLifeMonitor
//
//  Created by Claude on 22/11/2025.
//

import SwiftUI
import CoreData

struct HealthDataListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HealthSampleEntity.startDate, ascending: false)],
        animation: .default
    )
    private var samples: FetchedResults<HealthSampleEntity>

    @State private var selectedType: String? = nil

    private var sampleTypes: [String] {
        let types = Set(samples.compactMap { $0.sampleType })
        return Array(types).sorted()
    }

    private var filteredSamples: [HealthSampleEntity] {
        if let selectedType = selectedType {
            return samples.filter { $0.sampleType == selectedType }
        }
        return Array(samples)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            if !sampleTypes.isEmpty {
                Picker("Type", selection: $selectedType) {
                    Text("All (\(samples.count))").tag(nil as String?)
                    ForEach(sampleTypes, id: \.self) { type in
                        Text(formatSampleType(type)).tag(type as String?)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if samples.isEmpty {
                ContentUnavailableView(
                    "No Health Data",
                    systemImage: "heart.text.square",
                    description: Text("Health samples will appear here once they are collected from HealthKit.")
                )
            } else {
                List {
                    ForEach(filteredSamples, id: \.id) { sample in
                        HealthSampleRow(sample: sample)
                    }
                    .onDelete(perform: deleteSamples)
                }
            }
        }
        .navigationTitle("Health Data")
        .toolbar {
            if !samples.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(filteredSamples.count) samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func deleteSamples(offsets: IndexSet) {
        withAnimation {
            let samplesToDelete = offsets.map { filteredSamples[$0] }
            for sample in samplesToDelete {
                viewContext.delete(sample)
            }
            CoreDataManager.shared.save()
        }
    }

    private func formatSampleType(_ identifier: String) -> String {
        // Convert HKQuantityTypeIdentifier to readable name
        let name = identifier
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")

        // Add spaces before capitals
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result
    }
}

struct HealthSampleRow: View {
    let sample: HealthSampleEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForSampleType(sample.sampleType ?? ""))
                    .foregroundStyle(colorForSampleType(sample.sampleType ?? ""))
                Text(formatSampleType(sample.sampleType ?? "Unknown"))
                    .font(.headline)
            }

            HStack {
                Text(formatValue(sample.value, unit: sample.unit ?? ""))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            if let startDate = sample.startDate {
                Text(formatDate(startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let sourceName = sample.sourceName, !sourceName.isEmpty {
                Text("Source: \(sourceName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatSampleType(_ identifier: String) -> String {
        let name = identifier
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")

        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result
    }

    private func formatValue(_ value: Double, unit: String) -> String {
        // Sleep stages - display the stage name with duration
        if isSleepStage(unit) {
            return formatSleepStage(unit)
        }

        if unit == "category" {
            return categoryValueDescription(Int(value))
        }

        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0

        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return "\(formattedValue) \(unit)"
    }

    private func isSleepStage(_ unit: String) -> Bool {
        let sleepUnits = ["inBed", "asleep", "awake", "asleepCore", "asleepDeep", "asleepREM", "sleep"]
        return sleepUnits.contains(unit)
    }

    private func formatSleepStage(_ unit: String) -> String {
        switch unit {
        case "inBed": return "In Bed"
        case "asleep": return "Asleep"
        case "awake": return "Awake"
        case "asleepCore": return "Core Sleep"
        case "asleepDeep": return "Deep Sleep"
        case "asleepREM": return "REM Sleep"
        default: return "Sleep"
        }
    }

    private func categoryValueDescription(_ value: Int) -> String {
        // Common category value mappings
        switch value {
        case 0: return "Not Set"
        case 1: return "In Bed"
        case 2: return "Asleep"
        case 3: return "Awake"
        default: return "Value: \(value)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func iconForSampleType(_ type: String) -> String {
        if type.contains("HeartRate") || type.contains("Heart") {
            return "heart.fill"
        } else if type.contains("Step") {
            return "figure.walk"
        } else if type.contains("Distance") {
            return "figure.run"
        } else if type.contains("Sleep") {
            return "bed.double.fill"
        } else if type.contains("Energy") || type.contains("Calorie") {
            return "flame.fill"
        } else if type.contains("Oxygen") {
            return "lungs.fill"
        } else if type.contains("Blood") {
            return "drop.fill"
        } else if type.contains("Weight") || type.contains("Mass") {
            return "scalemass.fill"
        } else if type.contains("Respiratory") {
            return "wind"
        } else if type.contains("Audio") || type.contains("Hearing") {
            return "ear.fill"
        } else if type.contains("Mindful") {
            return "brain.head.profile"
        } else if type.contains("Workout") || type.contains("Exercise") {
            return "figure.strengthtraining.traditional"
        } else if type.contains("Flight") || type.contains("Stair") {
            return "figure.stairs"
        } else if type.contains("Stand") {
            return "figure.stand"
        } else if type.contains("Walking") {
            return "figure.walk"
        } else if type.contains("Swimming") {
            return "figure.pool.swim"
        } else if type.contains("Cycling") {
            return "bicycle"
        }
        return "heart.text.square"
    }

    private func colorForSampleType(_ type: String) -> Color {
        if type.contains("HeartRate") || type.contains("Heart") {
            return .red
        } else if type.contains("Step") || type.contains("Distance") {
            return .green
        } else if type.contains("Sleep") {
            return .purple
        } else if type.contains("Energy") || type.contains("Calorie") {
            return .orange
        } else if type.contains("Oxygen") {
            return .blue
        } else if type.contains("Blood") {
            return .red
        }
        return .primary
    }
}

#Preview {
    HealthDataListView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
