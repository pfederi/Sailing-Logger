import Foundation

struct Coordinates: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    func formattedNautical() -> String {
        // ... bestehende Implementierung ...
    }
} 