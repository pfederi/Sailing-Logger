import Foundation
import SwiftUI

@MainActor
class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private let savePath = FileManager.documentsDirectory.appendingPathComponent("SavedEntries")
    @Published var importStats: ImportStats?
    
    init() {
        loadEntries()
    }
    
    func addEntry(_ entry: LogEntry) {
        entries.append(entry)
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: savePath, options: [.atomic, .completeFileProtection])
        } catch {
            print("Unable to save data: \(error.localizedDescription)")
        }
    }
    
    private func loadEntries() {
        do {
            let data = try Data(contentsOf: savePath)
            entries = try JSONDecoder().decode([LogEntry].self, from: data)
            print("Loaded \(entries.count) entries")
        } catch {
            entries = []
            print("No saved entries found")
        }
    }
    
    func deleteEntry(_ entry: LogEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }
    
    func updateEntry(_ entry: LogEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            save()
        }
    }
    
    func deleteAllEntries() {
        entries.removeAll()
        save()
    }
    
    func importEntries(_ newEntries: [LogEntry]) {
        var addedCount = 0
        var duplicateCount = 0
        
        for entry in newEntries {
            if !entries.contains(where: { $0.id == entry.id }) {
                entries.append(entry)
                addedCount += 1
            } else {
                duplicateCount += 1
            }
        }
        
        // Sortiere die Einträge nach Timestamp
        entries.sort { $0.timestamp > $1.timestamp }
        
        save()
        
        // Aktualisiere die Import-Statistik
        importStats = ImportStats(
            totalProcessed: newEntries.count,
            added: addedCount,
            duplicates: duplicateCount
        )
    }
}

// Neue Struktur für Import-Statistiken
struct ImportStats {
    let totalProcessed: Int
    let added: Int
    let duplicates: Int
} 
