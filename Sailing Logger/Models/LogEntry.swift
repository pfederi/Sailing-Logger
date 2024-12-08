import Foundation
import SwiftUI
import MapKit
import UniformTypeIdentifiers

class LogEntry: Identifiable, ObservableObject, Codable, Hashable, Transferable {
    let id: UUID
    var timestamp: Date
    let coordinates: Coordinates
    let distance: Double
    let magneticCourse: Double
    let courseOverGround: Double
    let barometer: Double
    let temperature: Double
    let visibility: Int
    let cloudCover: Int
    let wind: Wind
    let sailState: SailState
    let speed: Double
    let engineState: EngineState
    let maneuver: Maneuver?
    let notes: String?
    let sails: Sails
    let voyage: Voyage?
    @Published var locationDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, coordinates, distance, magneticCourse, courseOverGround
        case barometer, temperature, visibility, cloudCover, wind, sailState, speed
        case engineState, maneuver, notes, sails, voyage, locationDescription
    }
    
    required init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        coordinates: Coordinates,
        distance: Double,
        magneticCourse: Double = 0,
        courseOverGround: Double = 0,
        barometer: Double = 0,
        temperature: Double = 0,
        visibility: Int = 0,
        cloudCover: Int = 0,
        wind: Wind = Wind(direction: .none, speedKnots: 0, beaufortForce: 0),
        sailState: SailState = .none,
        speed: Double = 0,
        engineState: EngineState = .off,
        maneuver: Maneuver? = nil,
        notes: String? = nil,
        sails: Sails = Sails(),
        voyage: Voyage? = nil,
        locationDescription: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.coordinates = coordinates
        self.distance = distance
        self.magneticCourse = magneticCourse
        self.courseOverGround = courseOverGround
        self.barometer = barometer
        self.temperature = temperature
        self.visibility = visibility
        self.cloudCover = cloudCover
        self.wind = wind
        self.sailState = sailState
        self.speed = speed
        self.engineState = engineState
        self.maneuver = maneuver
        self.notes = notes
        self.sails = sails
        self.voyage = voyage
        self.locationDescription = locationDescription
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Versuche zuerst als Date zu decodieren
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else {
            // Fallback: Versuche als Double (Unix timestamp) zu decodieren
            let timeInterval = try container.decode(Double.self, forKey: .timestamp)
            timestamp = Date(timeIntervalSince1970: timeInterval)
        }
        
        coordinates = try container.decodeIfPresent(Coordinates.self, forKey: .coordinates) ?? Coordinates(latitude: 0, longitude: 0)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        magneticCourse = try container.decodeIfPresent(Double.self, forKey: .magneticCourse) ?? 0
        courseOverGround = try container.decodeIfPresent(Double.self, forKey: .courseOverGround) ?? 0
        barometer = try container.decodeIfPresent(Double.self, forKey: .barometer) ?? 0
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0
        visibility = try container.decodeIfPresent(Int.self, forKey: .visibility) ?? 0
        cloudCover = try container.decodeIfPresent(Int.self, forKey: .cloudCover) ?? 0
        wind = try container.decodeIfPresent(Wind.self, forKey: .wind) ?? Wind(direction: .none, speedKnots: 0, beaufortForce: 0)
        
        // SailState kann als String kommen
        if let stateString = try container.decodeIfPresent(String.self, forKey: .sailState) {
            sailState = SailState(rawValue: stateString) ?? .none
        } else {
            sailState = try container.decodeIfPresent(SailState.self, forKey: .sailState) ?? .none
        }
        
        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 0
        
        // EngineState kann als String kommen
        if let stateString = try container.decodeIfPresent(String.self, forKey: .engineState) {
            engineState = EngineState(rawValue: stateString) ?? .off
        } else {
            engineState = try container.decodeIfPresent(EngineState.self, forKey: .engineState) ?? .off
        }
        
        // Optional fields
        maneuver = try container.decodeIfPresent(Maneuver.self, forKey: .maneuver)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        sails = try container.decodeIfPresent(Sails.self, forKey: .sails) ?? Sails()
        voyage = try container.decodeIfPresent(Voyage.self, forKey: .voyage)
        locationDescription = try container.decodeIfPresent(String.self, forKey: .locationDescription)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinates, forKey: .coordinates)
        try container.encode(distance, forKey: .distance)
        try container.encode(magneticCourse, forKey: .magneticCourse)
        try container.encode(courseOverGround, forKey: .courseOverGround)
        try container.encode(barometer, forKey: .barometer)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(cloudCover, forKey: .cloudCover)
        try container.encode(wind, forKey: .wind)
        try container.encode(sailState, forKey: .sailState)
        try container.encode(speed, forKey: .speed)
        try container.encode(engineState, forKey: .engineState)
        try container.encodeIfPresent(maneuver, forKey: .maneuver)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(sails, forKey: .sails)
        try container.encodeIfPresent(voyage, forKey: .voyage)
        try container.encodeIfPresent(locationDescription, forKey: .locationDescription)
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
    
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.timestamp == rhs.timestamp &&
        lhs.coordinates == rhs.coordinates &&
        lhs.distance == rhs.distance &&
        lhs.magneticCourse == rhs.magneticCourse &&
        lhs.courseOverGround == rhs.courseOverGround &&
        lhs.barometer == rhs.barometer &&
        lhs.temperature == rhs.temperature &&
        lhs.visibility == rhs.visibility &&
        lhs.cloudCover == rhs.cloudCover &&
        lhs.wind == rhs.wind &&
        lhs.sailState == rhs.sailState &&
        lhs.speed == rhs.speed &&
        lhs.engineState == rhs.engineState &&
        lhs.maneuver == rhs.maneuver &&
        lhs.notes == rhs.notes &&
        lhs.sails == rhs.sails
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(coordinates)
        hasher.combine(distance)
        hasher.combine(magneticCourse)
        hasher.combine(courseOverGround)
        hasher.combine(barometer)
        hasher.combine(temperature)
        hasher.combine(visibility)
        hasher.combine(cloudCover)
        hasher.combine(wind)
        hasher.combine(sailState)
        hasher.combine(speed)
        hasher.combine(engineState)
        hasher.combine(maneuver)
        hasher.combine(notes)
        hasher.combine(sails)
    }
    
    func fetchLocationDescription() async {
        print("Fetching location for coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        
        if let description = locationDescription,
           !description.contains("°N") && !description.contains("°S") && 
           !description.contains("°E") && !description.contains("°W") {
            print("Using cached location: \(description)")
            return
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        // Setze die Locale auf Englisch
        let locale = Locale(identifier: "en_US")
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            if let placemark = placemarks.first {
                if let ocean = placemark.ocean {
                    await MainActor.run {
                        self.locationDescription = ocean
                    }
                    return
                }
                if let sea = placemark.inlandWater {
                    await MainActor.run {
                        self.locationDescription = sea
                    }
                    return
                }
                
                let description = [
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                
                print("Found location: \(description)")
                
                await MainActor.run {
                    self.locationDescription = description
                    print("Location set to: \(self.locationDescription ?? "")")
                }
            }
        } catch {
            print("Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
}

struct Coordinates: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func formattedNautical() -> String {
        let latDegrees = Int(abs(latitude))
        let latMinutes = (abs(latitude) - Double(latDegrees)) * 60
        let latDirection = latitude >= 0 ? "N" : "S"
        
        let lonDegrees = Int(abs(longitude))
        let lonMinutes = (abs(longitude) - Double(lonDegrees)) * 60
        let lonDirection = longitude >= 0 ? "E" : "W"
        
        return String(format: "%02d°%05.2f'%@  %03d°%05.2f'%@",
                     latDegrees, latMinutes, latDirection,
                     lonDegrees, lonMinutes, lonDirection)
    }
    
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum Compass: String, Codable, CaseIterable {
    case none = "-"
    case n = "N"
    case ne = "NE"
    case e = "E"
    case se = "SE"
    case s = "S"
    case sw = "SW"
    case w = "W"
    case nw = "NW"
}

struct Wind: Codable, Hashable {
    let direction: Compass
    let speedKnots: Double
    let beaufortForce: Int
    
    init(direction: Compass, speedKnots: Double, beaufortForce: Int) {
        self.direction = direction
        self.speedKnots = speedKnots
        self.beaufortForce = beaufortForce
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Direction kann als String kommen
        if let directionString = try container.decodeIfPresent(String.self, forKey: .direction)?.uppercased() {
            direction = Compass(rawValue: directionString) ?? .none
        } else {
            direction = .none
        }
        
        speedKnots = try container.decodeIfPresent(Double.self, forKey: .speedKnots) ?? 0
        beaufortForce = try container.decodeIfPresent(Int.self, forKey: .beaufortForce) ?? 0
    }
    
    private enum CodingKeys: String, CodingKey {
        case direction
        case speedKnots
        case beaufortForce
    }
}

enum SailState: String, Codable, CaseIterable, Hashable {
    case none = "No sails"
    case mainsail = "Mainsail only"
    case jib = "Jib only"
    case both = "Both sails"
}

enum EngineState: String, Codable, CaseIterable, Hashable {
    case off = "Engine off"
    case on = "Engine running"
}

