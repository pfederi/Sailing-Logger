enum Visibility: String, Codable, CaseIterable {
    case excellent = "Very good (> 10nm)"
    case good = "Good (5nm - 10nm)"
    case moderate = "Moderate (2nm - 5nm)"
    case poor = "Poor (0.5nm - 2nm)"
    case foggy = "Foggy (< 0.5nm)"
    
    var value: Int {
        switch self {
        case .excellent: return 10
        case .good: return 7
        case .moderate: return 3
        case .poor: return 1
        case .foggy: return 0
        }
    }
    
    static func from(nauticalMiles: Int) -> Visibility {
        switch nauticalMiles {
        case 10...: return .excellent
        case 5..<10: return .good
        case 2..<5: return .moderate
        case 1..<2: return .poor
        default: return .foggy
        }
    }
} 