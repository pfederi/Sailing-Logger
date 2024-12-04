import Foundation

struct CrewMember: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var role: CrewRole
    
    init(id: UUID = UUID(), name: String, role: CrewRole) {
        self.id = id
        self.name = name
        self.role = role
    }
}

enum CrewRole: String, Codable, CaseIterable {
    case skipper = "Skipper"
    case secondSkipper = "Second Skipper"
    case crew = "Crew"
}

class Voyage: Identifiable, Codable {
    let id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var crew: [CrewMember]
    var boatType: String
    var boatName: String
    var isActive: Bool
    var logEntries: [LogEntry]
    
    init(id: UUID = UUID(), 
         name: String, 
         startDate: Date = Date(),
         endDate: Date? = nil,
         crew: [CrewMember] = [],
         boatType: String,
         boatName: String,
         isActive: Bool = true,
         logEntries: [LogEntry] = []) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.crew = crew
        self.boatType = boatType
        self.boatName = boatName
        self.isActive = isActive
        self.logEntries = logEntries
    }
} 