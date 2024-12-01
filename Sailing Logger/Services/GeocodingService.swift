import CoreLocation
import Foundation
import MapKit

actor GeocodingService {
    static let shared = GeocodingService()
    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]
    
    func reverseGeocode(coordinates: CLLocationCoordinate2D) async throws -> String {
        let cacheKey = String(format: "%.4f,%.4f", coordinates.latitude, coordinates.longitude)
        print("🔍 Checking location: \(coordinates.latitude), \(coordinates.longitude)")
        
        if let cachedResult = cache[cacheKey] {
            return cachedResult
        }
        
        let location = CLLocation(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "en_US")
            )
            if let placemark = placemarks.first,
               let name = placemark.ocean ?? placemark.name {
                cache[cacheKey] = name
                return name
            }
            throw GeocodingError.noPlacemarkFound
        } catch {
            print("❌ Geocoding error: \(error)")
            let description = String(format: "%.3f°N %.3f°E", coordinates.latitude, coordinates.longitude)
            cache[cacheKey] = description
            return description
        }
    }
    
    enum GeocodingError: Error {
        case noPlacemarkFound
    }
} 