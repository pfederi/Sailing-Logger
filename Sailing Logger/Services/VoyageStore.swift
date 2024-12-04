import Foundation

@MainActor
class VoyageStore: ObservableObject {
    @Published var voyages: [Voyage] = []
    @Published private(set) var activeVoyage: Voyage?
    
    private let savePath = FileManager.documentsDirectory.appendingPathComponent("SavedVoyages")
    
    var hasActiveVoyage: Bool {
        print("Checking hasActiveVoyage:")
        print("Active voyage: \(activeVoyage != nil)")
        return activeVoyage != nil
    }
    
    init() {
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
            save()
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
} 