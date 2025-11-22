//
//  LocationCategorizer.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 22/11/2025.
//

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

class LocationCategorizer {
    static let shared = LocationCategorizer()

    private let geocoder = CLGeocoder()
    private let userDefaults = UserDefaults.standard

    // Keys for storing user-defined locations
    private let homeLocationKey = "homeLocation"
    private let workLocationKey = "workLocation"

    // Threshold for matching user-defined locations (meters)
    private let locationMatchThreshold: CLLocationDistance = 150

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
        // First check user-defined locations
        if let category = checkUserDefinedLocations(location) {
            // Still get address info for display
            reverseGeocode(location: location) { placeName, address in
                completion(CategorizedLocation(
                    category: category,
                    placeName: placeName,
                    address: address
                ))
            }
            return
        }

        // Use reverse geocoding to determine category
        reverseGeocode(location: location) { [weak self] placeName, address in
            guard let self = self else {
                completion(CategorizedLocation(category: .other, placeName: placeName, address: address))
                return
            }

            let category = self.determineCategory(
                placeName: placeName,
                address: address,
                timestamp: location.timestamp
            )

            completion(CategorizedLocation(
                category: category,
                placeName: placeName,
                address: address
            ))
        }
    }

    private func checkUserDefinedLocations(_ location: CLLocation) -> LocationCategory? {
        // Check home
        if let homeCoord = getHomeLocation() {
            let homeLocation = CLLocation(latitude: homeCoord.latitude, longitude: homeCoord.longitude)
            if location.distance(from: homeLocation) < locationMatchThreshold {
                return .home
            }
        }

        // Check work
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

    private func determineCategory(placeName: String?, address: String?, timestamp: Date) -> LocationCategory {
        let combinedText = [placeName, address]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        // Healthcare keywords
        let healthcareKeywords = ["hospital", "clinic", "medical", "doctor", "health", "pharmacy", "urgent care", "emergency"]
        if healthcareKeywords.contains(where: { combinedText.contains($0) }) {
            return .healthcare
        }

        // Shopping keywords
        let shoppingKeywords = ["mall", "store", "shop", "market", "walmart", "target", "costco", "grocery", "supermarket"]
        if shoppingKeywords.contains(where: { combinedText.contains($0) }) {
            return .shopping
        }

        // Dining keywords
        let diningKeywords = ["restaurant", "cafe", "coffee", "starbucks", "mcdonald", "food", "diner", "bistro", "bar", "pub"]
        if diningKeywords.contains(where: { combinedText.contains($0) }) {
            return .dining
        }

        // Fitness keywords
        let fitnessKeywords = ["gym", "fitness", "yoga", "crossfit", "planet fitness", "24 hour", "athletic"]
        if fitnessKeywords.contains(where: { combinedText.contains($0) }) {
            return .fitness
        }

        // Leisure keywords
        let leisureKeywords = ["theater", "cinema", "movie", "museum", "library", "park", "recreation", "entertainment"]
        if leisureKeywords.contains(where: { combinedText.contains($0) }) {
            return .leisure
        }

        // Transit keywords
        let transitKeywords = ["airport", "station", "terminal", "bus stop", "subway", "metro", "train"]
        if transitKeywords.contains(where: { combinedText.contains($0) }) {
            return .transit
        }

        // Outdoors keywords
        let outdoorsKeywords = ["trail", "hiking", "nature", "beach", "lake", "mountain", "forest"]
        if outdoorsKeywords.contains(where: { combinedText.contains($0) }) {
            return .outdoors
        }

        // Time-based heuristics for uncategorized locations
        let hour = Calendar.current.component(.hour, from: timestamp)
        let isWeekday = !Calendar.current.isDateInWeekend(timestamp)

        // If it's a weekday during typical work hours, might be work
        if isWeekday && hour >= 9 && hour <= 17 {
            // Could be work, but we're not certain without user-defined location
            return .other
        }

        // Late night is likely home
        if hour >= 22 || hour <= 6 {
            return .other // Could be home but we're not certain
        }

        return .other
    }
}
