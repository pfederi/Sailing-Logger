import Foundation

@MainActor
class VoyageStore: ObservableObject {
    @Published var voyages: [Voyage] = []
    @Published private(set) var activeVoyage: Voyage?
    private let locationManager: LocationManager
    
    private let savePath = FileManager.documentsDirectory.appendingPathComponent("SavedVoyages")
    
    var hasActiveVoyage: Bool {
        print("Checking hasActiveVoyage:")
        print("Active voyage: \(activeVoyage != nil)")
        return activeVoyage != nil
    }
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        self.voyages = []
        loadVoyages()
    }
    
    func addVoyage(_ voyage: Voyage) {
        print("Adding new voyage: \(voyage.name)")
        voyages.append(voyage)
        activeVoyage = voyage
        save()
    }
    
    func endVoyage(_ voyage: Voyage) {
        print("Ending voyage: \(voyage.name)")
        if let index = voyages.firstIndex(where: { $0.id == voyage.id }) {
            // Stoppe das Tracking automatisch
            if voyages[index].isTracking {
                updateVoyageTracking(voyages[index], isTracking: false)
            }
            
            voyages[index].logEntries = voyage.logEntries
            voyages[index].isActive = false
            voyages[index].endDate = Date()
            activeVoyage = nil
            save()
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(voyages)
            try data.write(to: savePath, options: [.atomic, .completeFileProtection])
        } catch {
            print("Unable to save voyages: \(error.localizedDescription)")
        }
    }
    
    private func loadVoyages() {
        do {
            let data = try Data(contentsOf: savePath)
            voyages = try JSONDecoder().decode([Voyage].self, from: data)
            
            activeVoyage = nil
            
            for voyage in voyages {
                if voyage.isActive && voyage.endDate == nil {
                    activeVoyage = voyage
                    print("Found active voyage: \(voyage.name)")
                    break
                } else if voyage.isActive && voyage.endDate != nil {
                    if let index = voyages.firstIndex(where: { $0.id == voyage.id }) {
                        voyages[index].isActive = false
                        print("Deactivating completed voyage: \(voyage.name)")
                    }
                }
            }
            
            if voyages.contains(where: { $0.isActive && $0.endDate != nil }) {
                save()
            }
            
            print("Loaded voyages: \(voyages.count)")
            print("Active voyage status: \(activeVoyage?.name ?? "none")")
        } catch {
            voyages = []
            activeVoyage = nil
            print("No saved voyages found or error loading voyages")
        }
    }
    
    func resetActiveVoyageIfCompleted() {
        if let active = activeVoyage, active.endDate != nil {
            print("Resetting completed voyage: \(active.name)")
            if let index = voyages.firstIndex(where: { $0.id == active.id }) {
                voyages[index].isActive = false
                activeVoyage = nil
                save()
            }
        }
    }
    
    func updateVoyage(_ voyage: Voyage, name: String, crew: [CrewMember], boatType: String, boatName: String) {
        if let index = voyages.firstIndex(where: { $0.id == voyage.id }) {
            voyages[index].name = name
            voyages[index].crew = crew
            voyages[index].boatType = boatType
            voyages[index].boatName = boatName
            
            if voyages[index].id == activeVoyage?.id {
                activeVoyage = voyages[index]
            }
            
            save()
            
            objectWillChange.send()
        }
    }
    
    func deleteVoyage(_ voyage: Voyage) {
        voyages.removeAll { $0.id == voyage.id }
        if activeVoyage?.id == voyage.id {
            activeVoyage = nil
        }
        save()
    }
    
    func deleteLogEntry(_ entry: LogEntry, fromVoyage voyage: Voyage) {
        if let voyageIndex = voyages.firstIndex(where: { $0.id == voyage.id }) {
            voyages[voyageIndex].logEntries.removeAll { $0.id == entry.id }
            save()
        }
    }
    
    func restoreFromBackup(_ voyages: [Voyage]) {
        // Lösche zuerst alle bestehenden Voyages
        self.voyages.removeAll()
        
        // Füge die Backup-Voyages hinzu
        self.voyages = voyages
        
        // Finde die aktive Voyage
        activeVoyage = voyages.first(where: { $0.isActive && $0.endDate == nil })
        
        // Speichere die wiederhergestellten Daten
        save()
        
        print("📥 Restored \(voyages.count) voyages from backup")
        if let active = activeVoyage {
            print("📥 Active voyage: \(active.name)")
        }
    }
    
    func deleteAllData() {
        voyages.removeAll()
        activeVoyage = nil
        save()
        print("🗑 Deleted all voyages")
    }
    
    func updateVoyageTracking(_ voyage: Voyage, isTracking: Bool) {
        if let index = voyages.firstIndex(where: { $0.id == voyage.id }) {
            voyages[index].isTracking = isTracking
            // Ensure active voyage is updated
            if voyages[index].id == activeVoyage?.id {
                activeVoyage = voyages[index]
            }
            
            // Start/Stop tracking in LocationManager
            if isTracking {
                locationManager.startBackgroundTracking(interval: UserDefaults.standard.integer(forKey: "trackingInterval"))
            } else {
                locationManager.stopBackgroundTracking()
            }
            
            save()
            objectWillChange.send()
        }
    }
    
    func startTracking(_ voyage: Voyage) {
        voyage.isTracking = true
        locationManager.startBackgroundTracking(interval: 60)
        save()
    }
    
    func stopTracking(_ voyage: Voyage) {
        voyage.isTracking = false
        locationManager.stopBackgroundTracking()
        save()
    }
} 