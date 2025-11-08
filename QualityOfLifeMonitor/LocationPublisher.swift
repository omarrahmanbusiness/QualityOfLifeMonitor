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
    func publish(_ locations: [CLLocation]) {
        let context = CoreDataManager.shared.context

        for location in locations {
            let entity = LocationEntity(context: context)
            entity.latitude = location.coordinate.latitude
            entity.longitude = location.coordinate.longitude
            entity.timestamp = location.timestamp
            entity.altitude = location.altitude
            entity.speed = location.speed
        }

        CoreDataManager.shared.save()
    }
}
