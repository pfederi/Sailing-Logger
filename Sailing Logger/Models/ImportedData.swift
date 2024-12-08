import Foundation

struct ImportedData: Codable {
    let voyages: [Voyage]
    let entries: [LogEntry]
} 