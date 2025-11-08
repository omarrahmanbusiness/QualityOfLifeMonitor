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
                VStack(alignment: .leading) {
                    Text(location.timestamp.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .medium) } ?? "Unknown date")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text("Lat: \(location.latitude, specifier: "%.6f")")
                        Text("Lon: \(location.longitude, specifier: "%.6f")")
                        Text("Speed: \(location.speed, specifier: "%.2f") m/s")
                        Text("Alt: \(location.altitude, specifier: "%.2f") m")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        for i in 0..<2 {
            let newLocation = LocationEntity(context: context)
            newLocation.timestamp = Date().addingTimeInterval(Double(-i * 60))
            newLocation.latitude = 37.7749 + Double(i) * 0.01
            newLocation.longitude = -122.4194 - Double(i) * 0.01
            newLocation.speed = Double(i) * 1.5
            newLocation.altitude = 10.0 + Double(i) * 5.0
        }
        try? context.save()
    }
    
    return NavigationView {
        LocationDataListView()
            .environment(\.managedObjectContext, context)
    }
}
