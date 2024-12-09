import SwiftUI

struct VoyageArchiveView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @State private var selectedVoyage: Voyage?
    @State private var showingDeleteConfirmation = false
    @State private var voyageToDelete: Voyage?
    
    private var archivedVoyages: [Voyage] {
        voyageStore.voyages.filter { !$0.isActive }.reversed()
    }
    
    private var totalNauticalMiles: Double {
        archivedVoyages.reduce(0.0) { total, voyage in
            total + (voyage.logEntries.map({ $0.distance }).max() ?? 0.0)
        }
    }
    
    private var totalDays: Int {
        let calendar = Calendar.current
        return archivedVoyages.reduce(0) { total, voyage in
            if let lastEntry = voyage.logEntries.max(by: { $0.timestamp < $1.timestamp }) {
                let days = calendar.dateComponents([.day], from: voyage.startDate, to: lastEntry.timestamp).day ?? 0
                return total + max(1, days)
            }
            return total
        }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack {
                        Text("\(archivedVoyages.count)")
                            .font(.title.bold())
                        Text("Voyages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    VStack {
                        Text(String(format: "%.1f", totalNauticalMiles))
                            .font(.title.bold())
                        Text("Nautical Miles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    VStack {
                        Text("\(totalDays)")
                            .font(.title.bold())
                        Text("Days at Sea")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Existing Voyages List
            ForEach(archivedVoyages, id: \.id) { voyage in
                VoyageArchiveRow(
                    voyage: voyage,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore
                )
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    voyageToDelete = Array(archivedVoyages)[index]
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Voyage Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MaritimeColors.seafoam, for: .navigationBar)
        .confirmationDialog(
            "Delete Voyage",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    if let voyage = voyageToDelete {
                        voyageStore.deleteVoyage(voyage)
                    }
                }
            },
            message: {
                Text("Are you sure you want to delete this voyage and all its log entries? This action cannot be undone.")
            }
        )
        .toolbar {
            ToolbarItem(id: "delete", placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

private struct VoyageArchiveRow: View {
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    
    private var lastEntry: LogEntry? {
        voyage.logEntries.max(by: { $0.timestamp < $1.timestamp })
    }
    
    private var endDate: Date {
        lastEntry?.timestamp ?? voyage.startDate
    }
    
    var body: some View {
        NavigationLink {
            VoyageDetailView(
                voyage: voyage,
                voyageStore: voyageStore,
                locationManager: locationManager,
                tileManager: tileManager,
                logStore: logStore
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(voyage.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Date Range
                HStack {
                    Text(voyage.startDate.formatted(date: .abbreviated, time: .omitted))
                    Text("→")
                    Text(endDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                
                // Additional Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Boat:")
                            .fontWeight(.semibold)
                        Text("\(voyage.boatName) (\(voyage.boatType))")
                    }
                    .font(.caption)
                    .foregroundColor(.primary)
                
                    if !voyage.crew.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Crew:")
                                .fontWeight(.semibold)
                            Text(voyage.crew.map { $0.name }.joined(separator: ", "))
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                    }
                    
                    if let totalDistance = voyage.logEntries.map({ $0.distance }).max() {
                        HStack {
                            Text("Distance:")
                                .fontWeight(.semibold)
                            Text(String(format: "%.1f nm", totalDistance))
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                    }
                    
                    Text("\(voyage.logEntries.count) Log \(voyage.logEntries.count == 1 ? "Entry" : "Entries")")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct VoyageDetailsSection: View {
    let voyage: Voyage
    
    var body: some View {
        Section("Voyage Details") {
            VoyageDetailRow(title: "Boat", value: "\(voyage.boatName) (\(voyage.boatType))")
            VoyageDetailRow(title: "Period", value: "\(voyage.startDate.formatted(date: .long, time: .omitted)) - \(voyage.endDate?.formatted(date: .long, time: .omitted) ?? "ongoing")")
            if !voyage.crew.isEmpty {
                VoyageDetailRow(title: "Crew", value: voyage.crew.map { "\($0.name) (\($0.role.rawValue))" }.joined(separator: "\n"))
            }
        }
    }
}

private struct ArchivedLogEntriesSection: View {
    let date: String
    let entries: [LogEntry]
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @Binding var entryToDelete: LogEntry?
    @Binding var showingDeleteConfirmation: Bool
    
    var body: some View {
        Section(header: Text(date)) {
            ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                ArchivedLogEntryRow(
                    entry: entry,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore
                )
            }
        }
    }
}

private struct ArchivedLogEntryRow: View {
    let entry: LogEntry
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    
    var body: some View {
        NavigationLink {
            LogEntryDetailView(
                entry: entry,
                isArchived: true,
                voyageStore: voyageStore,
                locationManager: locationManager,
                tileManager: tileManager,
                logStore: logStore
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.engineState == .on ? "engine.combustion" : "sailboat")
                        .font(.system(size: 20))
                        .foregroundColor(MaritimeColors.navy)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                        
                        if let location = entry.locationDescription {
                            Text(location)
                                .font(.caption)
                        }
                        
                        Text(entry.coordinates.formattedNautical())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let maneuver = entry.maneuver {
                    Text(maneuver.rawValue)
                        .font(.body)
                }
                
                // Navigation Info
                if entry.distance > 0 || entry.magneticCourse > 0 || entry.courseOverGround > 0 || entry.speed > 0 {
                    HStack {
                        if entry.distance > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundColor(MaritimeColors.navy)
                                Text(String(format: "%.1f nm", entry.distance))
                            }
                        }
                        
                        if entry.magneticCourse > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .foregroundColor(MaritimeColors.navy)
                                Text(String(format: "%.0f°", entry.magneticCourse))
                            }
                        }
                        
                        if entry.courseOverGround > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari.fill")
                                    .foregroundColor(MaritimeColors.navy)
                                Text(String(format: "%.0f°", entry.courseOverGround))
                            }
                        }
                        
                        if entry.speed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .foregroundColor(MaritimeColors.navy)
                                Text(String(format: "%.1f kts", entry.speed))
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// Neue View für die Stats-Zeilen
private struct VoyageStatsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
} 