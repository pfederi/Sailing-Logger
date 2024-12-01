import Foundation
import CoreLocation
import ActivityKit

public struct Coordinates: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public func formattedNautical() -> String {
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
}

public enum Compass: String, Codable, CaseIterable {
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

public struct Wind: Codable, Hashable {
    public let direction: Compass
    public let speedKnots: Double
    public let beaufortForce: Int
    
    public init(direction: Compass, speedKnots: Double, beaufortForce: Int) {
        self.direction = direction
        self.speedKnots = speedKnots
        self.beaufortForce = beaufortForce
    }
}

public enum SailState: String, Codable, CaseIterable {
    case none = "No sails"
    case mainsail = "Mainsail only"
    case jib = "Jib only"
    case both = "Both sails"
}

public enum EngineState: String, Codable, CaseIterable {
    case off = "Engine off"
    case on = "Engine running"
}

public struct QuickLogAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let coordinates: Coordinates
        public let timestamp: Date
        public let speed: Double?
        public let course: Double?
        
        public init(coordinates: Coordinates, timestamp: Date, speed: Double? = nil, course: Double? = nil) {
            self.coordinates = coordinates
            self.timestamp = timestamp
            self.speed = speed
            self.course = course
        }
    }
    
    public init() {}
}

public struct SimpleLogEntry {
    public let timestamp: Date
    public let coordinates: Coordinates
    public let speed: Double
    public let course: Double
    
    public init(timestamp: Date, coordinates: Coordinates, speed: Double, course: Double) {
        self.timestamp = timestamp
        self.coordinates = coordinates
        self.speed = speed
        self.course = course
    }
}

public struct Sails: Codable, Hashable {
    public let mainSail: Bool
    public let jib: Bool
    public let genoa: Bool
    public let spinnaker: Bool
    public let reefing: Int
    
    public init(mainSail: Bool = false, jib: Bool = false, genoa: Bool = false, spinnaker: Bool = false, reefing: Int = 0) {
        self.mainSail = mainSail
        self.jib = jib
        self.genoa = genoa
        self.spinnaker = spinnaker
        self.reefing = reefing
    }
}

public enum Maneuver: String, Codable {
    case tack = "Tack"
    case jibe = "Jibe"
    case boxTurn = "Box Turn"
    case quickStop = "Quick Stop"
    case heaveToStart = "Heave To (Start)"
    case heaveToEnd = "Heave To (End)"
    case anchorDrop = "Anchor Drop"
    case anchorUp = "Anchor Up"
}

// Vereinfachte Version von LogEntry für das Widget
public struct QuickLogEntry: Codable {
    public let timestamp: Date
    public let coordinates: Coordinates
    public let speed: Double
    public let courseOverGround: Double
    
    public init(timestamp: Date = Date(),
         coordinates: Coordinates,
         speed: Double = 0,
         courseOverGround: Double = 0) {
        self.timestamp = timestamp
        self.coordinates = coordinates
        self.speed = speed
        self.courseOverGround = courseOverGround
    }
} 