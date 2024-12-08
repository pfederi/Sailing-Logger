import Foundation
import SwiftUI
import CoreLocation

@MainActor
class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private let savePath = FileManager.documentsDirectory.appendingPathComponent("SavedEntries")
    @Published var importStats: ImportStats?
    
    private let voyageStore: VoyageStore
    
    @Published private(set) var currentVoyage: Voyage?
    
    init(voyageStore: VoyageStore) {
        self.voyageStore = voyageStore
        self.currentVoyage = voyageStore.activeVoyage
        loadEntries()
        
        // Observer für Änderungen am activeVoyage
        Task { @MainActor in
            for await voyage in voyageStore.$activeVoyage.values {
                self.currentVoyage = voyage
                loadEntries()
            }
        }
    }
    
    var activeVoyageEntries: [LogEntry] {
        if let activeVoyage = voyageStore.activeVoyage {
            return entries.filter { entry in
                activeVoyage.logEntries.contains { $0.id == entry.id }
            }
        }
        return []
    }
    
    func updateCurrentVoyage(_ voyage: Voyage) {
        objectWillChange.send()
        currentVoyage = voyage
        loadEntries()
    }
    
    func addEntry(_ entry: LogEntry) {
        if let activeVoyage = voyageStore.activeVoyage {
            entries.append(entry)
            if let index = voyageStore.voyages.firstIndex(where: { $0.id == activeVoyage.id }) {
                voyageStore.voyages[index].logEntries.append(entry)
                voyageStore.save()
            }
            save()
        }
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
            let allEntries = try JSONDecoder().decode([LogEntry].self, from: data)
            
            // Nur Einträge des aktiven Voyages laden
            if let activeVoyage = voyageStore.activeVoyage {
                entries = allEntries.filter { entry in
                    activeVoyage.logEntries.contains { $0.id == entry.id }
                }
            } else {
                entries = []
            }
            
            print("Loaded \(entries.count) entries for active voyage")
        } catch {
            entries = []
            print("No saved entries found")
        }
    }
    
    func deleteEntry(_ entry: LogEntry) {
        entries.removeAll { $0.id == entry.id }
        if let activeVoyage = voyageStore.activeVoyage,
           let voyageIndex = voyageStore.voyages.firstIndex(where: { $0.id == activeVoyage.id }) {
            voyageStore.voyages[voyageIndex].logEntries.removeAll { $0.id == entry.id }
            voyageStore.save()
        }
        save()
    }
    
    func updateEntry(_ entry: LogEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            if let activeVoyage = voyageStore.activeVoyage,
               let voyageIndex = voyageStore.voyages.firstIndex(where: { $0.id == activeVoyage.id }),
               let entryIndex = voyageStore.voyages[voyageIndex].logEntries.firstIndex(where: { $0.id == entry.id }) {
                voyageStore.voyages[voyageIndex].logEntries[entryIndex] = entry
                voyageStore.save()
            }
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
    
    func updateLocationDescriptions() async {
        for index in entries.indices {
            if entries[index].locationDescription == nil {
                do {
                    let description = try await GeocodingService.shared.reverseGeocode(
                        coordinates: CLLocationCoordinate2D(
                            latitude: entries[index].coordinates.latitude,
                            longitude: entries[index].coordinates.longitude
                        )
                    )
                    entries[index].locationDescription = description
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    print("Fehler beim Geocoding für Eintrag \(entries[index].id): \(error)")
                }
            }
        }
        save()
    }
    
    func saveLocationDescription(for entry: LogEntry, description: String) {
        entry.locationDescription = description
        save()
    }
    
    func reloadEntries() {
        loadEntries()
    }
    
    var totalDistance: Double {
    entries
        .sorted { $0.timestamp > $1.timestamp }
        .first?
        .distance ?? 0
    }
}

// Neue Struktur für Import-Statistiken
struct ImportStats {
    let totalProcessed: Int
    let added: Int
    let duplicates: Int
} 
