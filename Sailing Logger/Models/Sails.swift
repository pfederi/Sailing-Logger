struct Sails: Codable, Hashable {
    var mainSail: Bool = false
    var jib: Bool = false
    var genoa: Bool = false
    var spinnaker: Bool = false
    var reefing: Int = 0
    
    static let maxReefing = 5
} 