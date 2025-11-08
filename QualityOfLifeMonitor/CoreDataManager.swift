//
//  CoreDataManager.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 08/11/2025.
//

// STEP 1: Create CoreDataManager.swift
import CoreData
import os

class CoreDataManager {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LocationModel")  // Your .xcdatamodeld file name
        container.loadPersistentStores { description, error in
            if let error = error {
                AppLog.coredata.error("Core Data failed to load: \(error.localizedDescription, privacy: .public)")
                FileLogger.shared.log("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                AppLog.coredata.error("Failed to save context: \(error.localizedDescription, privacy: .public)")
                FileLogger.shared.log("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Fetch Helpers
extension CoreDataManager {
    func fetchAllLocations() -> [LocationEntity] {
        let request: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            AppLog.coredata.error("Failed to fetch locations: \(error.localizedDescription, privacy: .public)")
            FileLogger.shared.log("Failed to fetch locations: \(error.localizedDescription)")
            return []
        }
    }

    func fetchRecentLocations(limit: Int) -> [LocationEntity] {
        let request: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        do {
            return try context.fetch(request)
        } catch {
            AppLog.coredata.error("Failed to fetch locations: \(error.localizedDescription, privacy: .public)")
            FileLogger.shared.log("Failed to fetch locations: \(error.localizedDescription)")
            return []
        }
    }
}
