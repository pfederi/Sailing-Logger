import Foundation
import MapKit

// Tile-Berechnung
extension Coordinates {
    func toTile(zoom: Int) -> (x: Int, y: Int) {
        TileCalculator.coordinateToTile(latitude: latitude, longitude: longitude, zoom: zoom)
    }
    
    func formatted() -> String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"
        
        let latDegrees = abs(latitude)
        let lonDegrees = abs(longitude)
        
        return String(format: "%.4f°%@ %.4f°%@",
                     latDegrees, latDirection,
                     lonDegrees, lonDirection)
    }
}

// Region-Vergleich
extension MKCoordinateRegion {
    func isEqual(to other: MKCoordinateRegion, tolerance: Double = 0.000001) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance &&
        abs(center.longitude - other.center.longitude) < tolerance &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
} 