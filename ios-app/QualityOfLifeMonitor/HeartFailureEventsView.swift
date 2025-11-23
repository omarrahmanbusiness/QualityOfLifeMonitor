//
//  HeartFailureEventsView.swift
//  QualityOfLifeMonitor
//

import SwiftUI
import CoreData
import os

struct HeartFailureEventsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeartFailureEventEntity.timestamp, ascending: false)],
        animation: .default)
    private var events: FetchedResults<HeartFailureEventEntity>

    @State private var showingAddSheet = false
    @State private var newNotes = ""

    var body: some View {
        List {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.timestamp ?? Date(), style: .date)
                        .font(.headline)
                    Text(event.timestamp ?? Date(), style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteEvents)
        }
        .navigationTitle("Heart Failure Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Event", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Section("Notes") {
                        TextEditor(text: $newNotes)
                            .frame(minHeight: 150)
                    }
                }
                .navigationTitle("Report Heart Failure")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            newNotes = ""
                            showingAddSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            addEvent()
                        }
                    }
                }
            }
        }
    }

    private func addEvent() {
        withAnimation {
            let newEvent = HeartFailureEventEntity(context: viewContext)
            newEvent.id = UUID()
            newEvent.timestamp = Date()
            newEvent.notes = newNotes.isEmpty ? nil : newNotes

            do {
                try viewContext.save()
                AppLog.coredata.info("Heart failure event saved")
                FileLogger.shared.log("Heart failure event saved")
            } catch {
                AppLog.coredata.error("Failed to save heart failure event: \(error.localizedDescription, privacy: .public)")
                FileLogger.shared.log("Failed to save heart failure event: \(error.localizedDescription)")
            }

            newNotes = ""
            showingAddSheet = false
        }
    }

    private func deleteEvents(offsets: IndexSet) {
        withAnimation {
            offsets.map { events[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                AppLog.coredata.error("Failed to delete heart failure event: \(error.localizedDescription, privacy: .public)")
                FileLogger.shared.log("Failed to delete heart failure event: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        HeartFailureEventsView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
