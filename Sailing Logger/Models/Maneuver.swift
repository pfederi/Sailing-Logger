enum Maneuver: String, Codable, CaseIterable, Hashable {
    // Navigation
    case tacking = "Tacking"
    case jibing = "Jibing"
    case courseChange = "Course Change"
    case heaveTo = "Heave To"
    case departure = "Departure"
    case docking = "Docking"
    
    
    // Sail Operations
    case hoistSails = "Hoist Sails"
    case strikeSails = "Strike Sails"
    case changeSails = "Change Sails"
    case reefing = "Reefing"
    
    // Special Maneuvers
    case anchoring = "Anchoring"
    case weatherManeuver = "Weather Maneuver"
    
    // Emergency
    case emergency = "Emergency Maneuver"
    case manOverboard = "Man Overboard (MOB)"
    case rescue = "Rescue Operation"
    
    var category: Category {
        switch self {
        case .tacking, .jibing, .courseChange, .heaveTo, .departure, .docking:
            return .navigation
        case .hoistSails, .strikeSails, .changeSails, .reefing:
            return .sailOperations
        case .anchoring, .weatherManeuver:
            return .specialManeuvers
        case .emergency, .manOverboard, .rescue:
            return .emergency
        }
    }
    
    enum Category: String, CaseIterable {
        case navigation = "Navigation"
        case sailOperations = "Sail Operations"
        case specialManeuvers = "Special Maneuvers"
        case emergency = "Emergency"
    }
} 
