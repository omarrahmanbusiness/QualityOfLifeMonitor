//
//  LocationPublisher.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 08/11/2025.
//

import _LocationEssentials
import CoreData
import CoreLocation

class LocationPublisher {
    private let categorizer = LocationCategorizer.shared

    func publish(_ locations: [CLLocation]) {
        let context = CoreDataManager.shared.context

        for location in locations {
            let entity = LocationEntity(context: context)
            entity.latitude = location.coordinate.latitude
            entity.longitude = location.coordinate.longitude
            entity.timestamp = location.timestamp
            entity.altitude = location.altitude
            entity.speed = location.speed

            // Categorize the location asynchronously
            categorizer.categorize(location: location) { [weak entity] result in
                guard let entity = entity else { return }

                DispatchQueue.main.async {
                    entity.category = result.category.rawValue
                    entity.placeName = result.placeName
                    entity.address = result.address
                    CoreDataManager.shared.save()
                }
            }
        }

        CoreDataManager.shared.save()
    }
}
