enum CloudCover: String, Codable, CaseIterable {
    case clear = "Clear Sky (0/8)"
    case lightlyCloudy = "Lightly Cloudy (1/8 - 3/8)"
    case cloudy = "Cloudy (4/8 - 6/8)"
    case overcast = "Overcast (7/8 - 8/8)"
    
    var value: Int {
        switch self {
        case .clear: return 0
        case .lightlyCloudy: return 2
        case .cloudy: return 5
        case .overcast: return 8
        }
    }
    
    static func from(oktas: Int) -> CloudCover {
        switch oktas {
        case 0: return .clear
        case 1...3: return .lightlyCloudy
        case 4...6: return .cloudy
        default: return .overcast
        }
    }
} 