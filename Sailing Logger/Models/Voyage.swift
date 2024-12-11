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

class Voyage: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var name: String
    @Published var boatName: String
    @Published var boatType: String
    @Published var startDate: Date
    @Published var endDate: Date?
    @Published var isTracking: Bool
    @Published var logEntries: [LogEntry]
    @Published var isActive: Bool
    @Published var crew: [CrewMember]
    
    enum CodingKeys: String, CodingKey {
        case id, name, boatName, boatType, startDate, endDate, isTracking, logEntries, isActive, crew
    }
    
    init(id: UUID = UUID(), name: String, boatName: String, boatType: String, startDate: Date = Date(), endDate: Date? = nil, isTracking: Bool = false, logEntries: [LogEntry] = [], isActive: Bool = true, crew: [CrewMember] = []) {
        self.id = id
        self.name = name
        self.boatName = boatName
        self.boatType = boatType
        self.startDate = startDate
        self.endDate = endDate
        self.isTracking = isTracking
        self.logEntries = logEntries
        self.isActive = isActive
        self.crew = crew
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        boatName = try container.decode(String.self, forKey: .boatName)
        boatType = try container.decode(String.self, forKey: .boatType)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isTracking = try container.decode(Bool.self, forKey: .isTracking)
        logEntries = try container.decode([LogEntry].self, forKey: .logEntries)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        crew = try container.decode([CrewMember].self, forKey: .crew)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(boatName, forKey: .boatName)
        try container.encode(boatType, forKey: .boatType)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(isTracking, forKey: .isTracking)
        try container.encode(logEntries, forKey: .logEntries)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(crew, forKey: .crew)
    }
} 