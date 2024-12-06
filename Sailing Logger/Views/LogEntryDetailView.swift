import SwiftUI
import MapKit
// Importieren Sie das Modul, das OpenSeaMapTileManager enthält
// import YourModuleName

struct LogEntryDetailView: View {
    @State var entry: LogEntry
    var isArchived: Bool = false  // Default ist false für normale Ansicht
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager // Verwenden Sie den korrekten Typ
    @ObservedObject var logStore: LogStore
    
    var body: some View {
        List {
            Section("Navigation") {
                DetailRow(icon: "location.fill", title: "Position", value: entry.coordinates.formattedNautical())
                if entry.magneticCourse > 0 {
                    DetailRow(icon: "safari", title: "C°", value: String(format: "%.1f°", entry.magneticCourse))
                }
            }
            
            .listSectionSpacing(.compact)
            
            Section {
                MapView(
                    locationManager: locationManager,
                    tileManager: tileManager,
                    coordinates: entry.coordinates,
                    logEntries: logStore.entries
                )
                .frame(height: 270)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(.compact)
            
            Section {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy)
                    Text("Distance")
                    Spacer()
                    Text(String(format: "%.1f nm", entry.distance))
                }
            }
            .listSectionSpacing(.compact)
            
            if let maneuver = entry.maneuver {
                Section("Maneuvers") {
                    HStack {
                        Image(systemName: "helm")
                            .frame(width: 24)
                            .foregroundColor(MaritimeColors.navy)
                        Text(maneuver.rawValue)
                    }
                }
            }
            
            if hasConditionsData {
                Section("Conditions") {
                    if entry.magneticCourse > 0 {
                        DetailRow(icon: "safari", title: "C°", value: String(format: "%.1f°", entry.magneticCourse))
                    }
                    if entry.courseOverGround > 0 {
                        DetailRow(icon: "safari.fill", title: "COG", value: String(format: "%.1f°", entry.courseOverGround))
                    }
                    if entry.speed > 0 {
                        DetailRow(icon: "speedometer", title: "SOG", value: String(format: "%.1f kts", entry.speed))
                    }
                    if entry.barometer != 0 {
                        DetailRow(icon: "barometer", title: "Barometer", value: String(format: "%.1f hPa", entry.barometer))
                    }
                    if entry.temperature != 0 {
                        DetailRow(icon: "thermometer.medium", title: "Temperature", value: String(format: "%.1f °C", entry.temperature))
                    }
                    if entry.visibility != 0 {
                        DetailRow(icon: "eye", title: "Visibility", value: "\(entry.visibility) nm")
                    }
                    if entry.cloudCover != 0 {
                        DetailRow(icon: "cloud", title: "Cloud Cover", value: "\(entry.cloudCover)/8")
                    }
                }
            }
            
            if entry.wind.speedKnots > 0 {
                Section("Wind") {
                    DetailRow(icon: "arrow.up.left.circle", title: "Direction", value: entry.wind.direction.rawValue.uppercased())
                    DetailRow(icon: "wind", title: "Speed", value: String(format: "%.1f kts", entry.wind.speedKnots))
                    DetailRow(icon: "gauge", title: "Force", value: "Bft \(entry.wind.beaufortForce)")
                }
            }
            
            if hasSailsSet {
                Section("Sails") {
                    HStack {
                        Image(systemName: "sailboat")
                            .frame(width: 24)
                            .foregroundColor(MaritimeColors.navy)
                        VStack(alignment: .leading) {
                            if entry.sails.mainSail {
                                Text("Main Sail")
                            }
                            if entry.sails.jib {
                                Text("Jib")
                            }
                            if entry.sails.genoa {
                                Text("Genoa")
                            }
                            if entry.sails.spinnaker {
                                Text("Spinnaker")
                            }
                            if entry.sails.reefing > 0 {
                                Text("Reefing: \(entry.sails.reefing)")
                            }
                        }
                    }
                }
            }
            
            Section {
                HStack {
                    Image(systemName: "engine.combustion")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy)
                    Text("Engine")
                    Spacer()
                    Text(entry.engineState == .on ? "Engine running" : "Engine off")
                }
            }
            
            if let notes = entry.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Log Entry Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isArchived {  // Nur anzeigen, wenn nicht archiviert
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Entry", systemImage: "pencil")
                            .foregroundColor(MaritimeColors.navy)
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(MaritimeColors.navy)
                }
            }
        }
        .confirmationDialog(
            "Delete Entry",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    logStore.deleteEntry(entry)
                    dismiss()
                }
            },
            message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
        )
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                EditLogEntryView(
                    logStore: logStore, 
                    entry: entry,
                    locationManager: locationManager,
                    tileManager: tileManager
                )
            }
        }
        .onChange(of: showingEditSheet) { oldValue, newValue in
            if !newValue {
                // Nach dem Schließen des EditSheet den Eintrag neu laden
                if let updatedEntry = logStore.entries.first(where: { $0.id == entry.id }) {
                    print("Updating detail view with entry: \(updatedEntry.id)")
                    print("Updated sails state: \(updatedEntry.sails)")
                    entry = updatedEntry
                }
            }
        }
    }
    
    private var hasConditionsData: Bool {
        return entry.magneticCourse > 0 ||
               entry.courseOverGround > 0 ||
               entry.speed > 0 ||
               entry.barometer != 0 ||
               entry.temperature != 0 ||
               entry.visibility != 0 ||
               entry.cloudCover != 0
    }
    
    private var hasSailsSet: Bool {
        return entry.sails.mainSail ||
               entry.sails.jib ||
               entry.sails.genoa ||
               entry.sails.spinnaker ||
               entry.sails.reefing > 0
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(MaritimeColors.navy)
            Text(title)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(value)
        }
    }
}
