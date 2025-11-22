//
//  LocationCategorizer.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 22/11/2025.
//

import CoreData
import CoreLocation
import Foundation
import os

enum LocationCategory: String, CaseIterable {
    case home = "Home"
    case work = "Work"
    case healthcare = "Healthcare"
    case shopping = "Shopping"
    case dining = "Dining"
    case fitness = "Fitness"
    case leisure = "Leisure"
    case transit = "Transit"
    case outdoors = "Outdoors"
    case other = "Other"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .healthcare: return "cross.case.fill"
        case .shopping: return "cart.fill"
        case .dining: return "fork.knife"
        case .fitness: return "figure.run"
        case .leisure: return "gamecontroller.fill"
        case .transit: return "car.fill"
        case .outdoors: return "leaf.fill"
        case .other: return "mappin"
        }
    }
}

struct CategorizedLocation {
    let category: LocationCategory
    let placeName: String?
    let address: String?
}

/// Context about a location derived from historical data and current state
struct LocationContext {
    let speed: Double
    let altitude: Double
    let timestamp: Date
    let visitCount: Int
    let totalDwellTime: TimeInterval
    let averageVisitDuration: TimeInterval
    let dayOfWeekPattern: [Int: Int] // weekday (1-7) -> visit count
    let hourPattern: [Int: Int] // hour (0-23) -> visit count
    let isFrequentLocation: Bool
    let isStationary: Bool
}

class LocationCategorizer {
    static let shared = LocationCategorizer()

    private let geocoder = CLGeocoder()
    private let userDefaults = UserDefaults.standard

    // Keys for storing user-defined locations
    private let homeLocationKey = "homeLocation"
    private let workLocationKey = "workLocation"

    // Thresholds
    private let locationMatchThreshold: CLLocationDistance = 150
    private let clusterRadius: CLLocationDistance = 100
    private let stationarySpeedThreshold: Double = 0.5 // m/s
    private let transitSpeedThreshold: Double = 2.0 // m/s (~7 km/h, walking pace)
    private let frequentVisitThreshold: Int = 3

    // MARK: - User-Defined Locations

    func setHomeLocation(_ coordinate: CLLocationCoordinate2D) {
        let dict = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
        userDefaults.set(dict, forKey: homeLocationKey)
    }

    func setWorkLocation(_ coordinate: CLLocationCoordinate2D) {
        let dict = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
        userDefaults.set(dict, forKey: workLocationKey)
    }

    func getHomeLocation() -> CLLocationCoordinate2D? {
        guard let dict = userDefaults.dictionary(forKey: homeLocationKey),
              let lat = dict["latitude"] as? Double,
              let lon = dict["longitude"] as? Double else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func getWorkLocation() -> CLLocationCoordinate2D? {
        guard let dict = userDefaults.dictionary(forKey: workLocationKey),
              let lat = dict["latitude"] as? Double,
              let lon = dict["longitude"] as? Double else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Categorization

    func categorize(location: CLLocation, completion: @escaping (CategorizedLocation) -> Void) {
        // Build context from historical data
        let context = buildLocationContext(for: location)

        // Check if in transit based on speed
        if context.speed > transitSpeedThreshold && !context.isStationary {
            reverseGeocode(location: location) { placeName, address in
                completion(CategorizedLocation(
                    category: .transit,
                    placeName: placeName,
                    address: address
                ))
            }
            return
        }

        // Check user-defined locations
        if let category = checkUserDefinedLocations(location) {
            reverseGeocode(location: location) { placeName, address in
                completion(CategorizedLocation(
                    category: category,
                    placeName: placeName,
                    address: address
                ))
            }
            return
        }

        // Use reverse geocoding with rich context
        reverseGeocodeWithContext(location: location, context: context, completion: completion)
    }

    private func buildLocationContext(for location: CLLocation) -> LocationContext {
        let historicalLocations = fetchNearbyHistoricalLocations(location)

        // Calculate visit patterns
        var visitCount = 0
        var totalDwellTime: TimeInterval = 0
        var dayPattern: [Int: Int] = [:]
        var hourPattern: [Int: Int] = [:]

        let calendar = Calendar.current

        // Group consecutive visits to calculate dwell time
        var lastTimestamp: Date?
        var currentDwell: TimeInterval = 0

        for entity in historicalLocations.sorted(by: { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }) {
            guard let timestamp = entity.timestamp else { continue }

            visitCount += 1

            // Day of week pattern (1 = Sunday, 7 = Saturday)
            let weekday = calendar.component(.weekday, from: timestamp)
            dayPattern[weekday, default: 0] += 1

            // Hour pattern
            let hour = calendar.component(.hour, from: timestamp)
            hourPattern[hour, default: 0] += 1

            // Calculate dwell time (time between consecutive visits at same location)
            if let last = lastTimestamp {
                let interval = timestamp.timeIntervalSince(last)
                // If less than 2 hours between readings, consider it same visit
                if interval < 7200 {
                    currentDwell += interval
                } else {
                    totalDwellTime += currentDwell
                    currentDwell = 0
                }
            }
            lastTimestamp = timestamp
        }
        totalDwellTime += currentDwell

        let averageDuration = visitCount > 0 ? totalDwellTime / Double(visitCount) : 0

        return LocationContext(
            speed: location.speed >= 0 ? location.speed : 0,
            altitude: location.altitude,
            timestamp: location.timestamp,
            visitCount: visitCount,
            totalDwellTime: totalDwellTime,
            averageVisitDuration: averageDuration,
            dayOfWeekPattern: dayPattern,
            hourPattern: hourPattern,
            isFrequentLocation: visitCount >= frequentVisitThreshold,
            isStationary: location.speed >= 0 && location.speed < stationarySpeedThreshold
        )
    }

    private func fetchNearbyHistoricalLocations(_ location: CLLocation) -> [LocationEntity] {
        let allLocations = CoreDataManager.shared.fetchAllLocations()

        return allLocations.filter { entity in
            let entityLocation = CLLocation(latitude: entity.latitude, longitude: entity.longitude)
            return location.distance(from: entityLocation) < clusterRadius
        }
    }

    private func checkUserDefinedLocations(_ location: CLLocation) -> LocationCategory? {
        if let homeCoord = getHomeLocation() {
            let homeLocation = CLLocation(latitude: homeCoord.latitude, longitude: homeCoord.longitude)
            if location.distance(from: homeLocation) < locationMatchThreshold {
                return .home
            }
        }

        if let workCoord = getWorkLocation() {
            let workLocation = CLLocation(latitude: workCoord.latitude, longitude: workCoord.longitude)
            if location.distance(from: workLocation) < locationMatchThreshold {
                return .work
            }
        }

        return nil
    }

    private func reverseGeocode(location: CLLocation, completion: @escaping (String?, String?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                AppLog.location.error("Reverse geocoding failed: \(error?.localizedDescription ?? "Unknown error", privacy: .public)")
                completion(nil, nil)
                return
            }

            let placeName = placemark.name
            let address = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            completion(placeName, address.isEmpty ? nil : address)
        }
    }

    private func reverseGeocodeWithContext(location: CLLocation, context: LocationContext, completion: @escaping (CategorizedLocation) -> Void) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else {
                completion(CategorizedLocation(category: .other, placeName: nil, address: nil))
                return
            }

            guard let placemark = placemarks?.first, error == nil else {
                AppLog.location.error("Reverse geocoding failed: \(error?.localizedDescription ?? "Unknown error", privacy: .public)")
                let category = self.inferCategoryFromContext(context: context, placemark: nil)
                completion(CategorizedLocation(category: category, placeName: nil, address: nil))
                return
            }

            let placeName = placemark.name
            let address = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            let category = self.determineCategory(
                placemark: placemark,
                context: context
            )

            completion(CategorizedLocation(
                category: category,
                placeName: placeName,
                address: address.isEmpty ? nil : address
            ))
        }
    }

    private func determineCategory(placemark: CLPlacemark, context: LocationContext) -> LocationCategory {
        // Build searchable text from all available placemark data
        let searchableText = buildSearchableText(from: placemark)

        // 1. Check place type keywords first (highest confidence)
        if let keywordCategory = matchKeywords(in: searchableText) {
            return keywordCategory
        }

        // 2. Infer from behavioral patterns and context
        return inferCategoryFromContext(context: context, placemark: placemark)
    }

    private func buildSearchableText(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        // Primary identifiers
        if let name = placemark.name { components.append(name) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }

        // Areas of interest (e.g., "Golden Gate Park", "Financial District")
        if let areasOfInterest = placemark.areasOfInterest {
            components.append(contentsOf: areasOfInterest)
        }

        // Additional context
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let locality = placemark.locality { components.append(locality) }

        return components.joined(separator: " ").lowercased()
    }

    private func matchKeywords(in text: String) -> LocationCategory? {
        // Healthcare - highest priority for health monitoring app
        let healthcareKeywords = [
            "hospital", "clinic", "medical", "doctor", "health", "pharmacy",
            "urgent care", "emergency", "dental", "physician", "laboratory",
            "diagnostic", "radiology", "cardiology", "therapy", "rehabilitation"
        ]
        if healthcareKeywords.contains(where: { text.contains($0) }) {
            return .healthcare
        }

        // Fitness
        let fitnessKeywords = [
            "gym", "fitness", "yoga", "crossfit", "athletic", "sport",
            "swimming pool", "tennis", "basketball", "recreation center",
            "pilates", "martial arts", "boxing", "climbing"
        ]
        if fitnessKeywords.contains(where: { text.contains($0) }) {
            return .fitness
        }

        // Shopping
        let shoppingKeywords = [
            "mall", "store", "shop", "market", "walmart", "target", "costco",
            "grocery", "supermarket", "outlet", "plaza", "retail", "pharmacy",
            "drugstore", "department store", "shopping center"
        ]
        if shoppingKeywords.contains(where: { text.contains($0) }) {
            return .shopping
        }

        // Dining
        let diningKeywords = [
            "restaurant", "cafe", "coffee", "starbucks", "mcdonald", "food",
            "diner", "bistro", "bar", "pub", "brewery", "bakery", "pizzeria",
            "grill", "kitchen", "eatery", "tavern", "lounge"
        ]
        if diningKeywords.contains(where: { text.contains($0) }) {
            return .dining
        }

        // Leisure/Entertainment
        let leisureKeywords = [
            "theater", "theatre", "cinema", "movie", "museum", "library",
            "gallery", "entertainment", "arcade", "bowling", "amusement",
            "zoo", "aquarium", "concert", "stadium", "arena"
        ]
        if leisureKeywords.contains(where: { text.contains($0) }) {
            return .leisure
        }

        // Transit
        let transitKeywords = [
            "airport", "station", "terminal", "bus stop", "subway", "metro",
            "train", "transit", "ferry", "port", "parking", "gas station",
            "fuel", "rental car"
        ]
        if transitKeywords.contains(where: { text.contains($0) }) {
            return .transit
        }

        // Outdoors
        let outdoorsKeywords = [
            "park", "trail", "hiking", "nature", "beach", "lake", "mountain",
            "forest", "garden", "reserve", "wilderness", "campground",
            "playground", "field", "golf"
        ]
        if outdoorsKeywords.contains(where: { text.contains($0) }) {
            return .outdoors
        }

        return nil
    }

    private func inferCategoryFromContext(context: LocationContext, placemark: CLPlacemark?) -> LocationCategory {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: context.timestamp)
        let weekday = calendar.component(.weekday, from: context.timestamp)
        let isWeekend = weekday == 1 || weekday == 7

        // High confidence inferences based on behavioral patterns

        // 1. Frequent location with long dwell times at night = likely home
        if context.isFrequentLocation &&
           context.averageVisitDuration > 3600 && // > 1 hour average
           isNightTimePattern(context.hourPattern) {
            return .home
        }

        // 2. Frequent location with regular weekday daytime pattern = likely work
        if context.isFrequentLocation &&
           context.averageVisitDuration > 1800 && // > 30 min average
           isWorkTimePattern(context.hourPattern, dayPattern: context.dayOfWeekPattern) {
            return .work
        }

        // 3. Time-based heuristics for new/infrequent locations
        if !context.isFrequentLocation {
            // Late night (10pm - 6am) at stationary location
            if (hour >= 22 || hour <= 6) && context.isStationary {
                return .home
            }

            // Weekday business hours at stationary location
            if !isWeekend && hour >= 9 && hour <= 17 && context.isStationary {
                // Could be work, but without history we're uncertain
                if context.totalDwellTime > 1800 { // Been here > 30 min
                    return .work
                }
            }

            // Weekend daytime
            if isWeekend && hour >= 10 && hour <= 20 {
                return .leisure
            }
        }

        return .other
    }

    private func isNightTimePattern(_ hourPattern: [Int: Int]) -> Bool {
        // Check if most visits occur during night/early morning (10pm - 8am)
        let nightHours = [22, 23, 0, 1, 2, 3, 4, 5, 6, 7]
        let nightVisits = nightHours.reduce(0) { $0 + (hourPattern[$1] ?? 0) }
        let totalVisits = hourPattern.values.reduce(0, +)

        guard totalVisits > 0 else { return false }
        return Double(nightVisits) / Double(totalVisits) > 0.5
    }

    private func isWorkTimePattern(_ hourPattern: [Int: Int], dayPattern: [Int: Int]) -> Bool {
        // Check if most visits occur during work hours (8am - 6pm) on weekdays
        let workHours = Array(8...18)
        let workVisits = workHours.reduce(0) { $0 + (hourPattern[$1] ?? 0) }
        let totalHourVisits = hourPattern.values.reduce(0, +)

        // Check weekday dominance (Mon=2 through Fri=6)
        let weekdayVisits = (2...6).reduce(0) { $0 + (dayPattern[$1] ?? 0) }
        let totalDayVisits = dayPattern.values.reduce(0, +)

        guard totalHourVisits > 0, totalDayVisits > 0 else { return false }

        let workHourRatio = Double(workVisits) / Double(totalHourVisits)
        let weekdayRatio = Double(weekdayVisits) / Double(totalDayVisits)

        return workHourRatio > 0.6 && weekdayRatio > 0.6
    }
}
