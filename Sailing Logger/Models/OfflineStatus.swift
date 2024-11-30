import SwiftUI

enum OfflineStatus: Equatable {
    case checking
    case online
    case offline
    case partiallyOffline(percentage: Double)
    
    var icon: String {
        switch self {
        case .checking: return "hourglass"
        case .online: return "wifi"
        case .offline: return "wifi.slash"
        case .partiallyOffline: return "wifi.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .checking: return .gray
        case .online: return .orange
        case .offline: return .green
        case .partiallyOffline: return .yellow
        }
    }
    
    var text: String {
        switch self {
        case .checking: return "Checking..."
        case .online: return "Online"
        case .offline: return "Offline"
        case .partiallyOffline(let percentage):
            return "Partially Offline (\(Int(percentage * 100))%)"
        }
    }
    
    static func == (lhs: OfflineStatus, rhs: OfflineStatus) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking): return true
        case (.online, .online): return true
        case (.offline, .offline): return true
        case (.partiallyOffline(let lhsPercentage), .partiallyOffline(let rhsPercentage)):
            return lhsPercentage == rhsPercentage
        default:
            return false
        }
    }
} 