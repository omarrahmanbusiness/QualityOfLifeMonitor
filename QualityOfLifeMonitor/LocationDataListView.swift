import SwiftUI
import CoreData

struct LocationDataListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.timestamp, order: .reverse)],
        animation: .default
    )
    private var locations: FetchedResults<LocationEntity>
    
    var body: some View {
        List {
            ForEach(locations) { location in
                VStack(alignment: .leading, spacing: 6) {
                    // Category and place name header
                    HStack {
                        if let categoryString = location.category,
                           let category = LocationCategory(rawValue: categoryString) {
                            Image(systemName: category.icon)
                                .foregroundColor(.accentColor)
                            Text(category.rawValue)
                                .font(.headline)
                        } else {
                            Image(systemName: "mappin")
                                .foregroundColor(.secondary)
                            Text("Uncategorized")
                                .font(.headline)
                        }
                        Spacer()
                    }

                    // Place name and address
                    if let placeName = location.placeName {
                        Text(placeName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    if let address = location.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Timestamp
                    Text(location.timestamp.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "Unknown date")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Coordinates (collapsible detail)
                    HStack(spacing: 8) {
                        Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                        if location.speed > 0 {
                            Text("• \(location.speed, specifier: "%.1f") m/s")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteLocations)
        }
        .navigationTitle("Location")
    }
    
    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = locations[index]
            viewContext.delete(location)
        }
        do {
            try viewContext.save()
        } catch {
            // Handle the Core Data error appropriately in a real app
            print("Error deleting location: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        return container
    }()
    
    let context = container.viewContext
    
    // Insert sample data if empty
    if (try? context.count(for: NSFetchRequest<LocationEntity>(entityName: "LocationEntity"))) ?? 0 == 0 {
        let sampleData: [(String, String, String)] = [
            ("Home", "123 Main St", "123 Main St, San Francisco, CA 94102"),
            ("Shopping", "Whole Foods Market", "450 Rhode Island St, San Francisco, CA 94107")
        ]
        for i in 0..<2 {
            let newLocation = LocationEntity(context: context)
            newLocation.timestamp = Date().addingTimeInterval(Double(-i * 3600))
            newLocation.latitude = 37.7749 + Double(i) * 0.01
            newLocation.longitude = -122.4194 - Double(i) * 0.01
            newLocation.speed = Double(i) * 1.5
            newLocation.altitude = 10.0 + Double(i) * 5.0
            newLocation.category = sampleData[i].0
            newLocation.placeName = sampleData[i].1
            newLocation.address = sampleData[i].2
        }
        try? context.save()
    }
    
    return NavigationView {
        LocationDataListView()
            .environment(\.managedObjectContext, context)
    }
}

