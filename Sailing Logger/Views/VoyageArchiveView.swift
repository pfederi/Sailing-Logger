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
    
    var body: some View {
        List {
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
    }
}

private struct VoyageArchiveRow: View {
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    
    private var lastEntry: LogEntry? {
        voyage.logEntries.sorted { $0.timestamp > $1.timestamp }.first
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
                    Text(lastEntry?.timestamp.formatted(date: .abbreviated, time: .omitted) ?? "ongoing")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                // Additional Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(voyage.boatName) (\(voyage.boatType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !voyage.crew.isEmpty {
                        Text("Crew: \(voyage.crew.map { $0.name }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(voyage.logEntries.count) Log Entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct VoyageDetailView: View {
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @State private var entryToDelete: LogEntry?
    @State private var showingDeleteConfirmation = false
    @State private var showingVoyageLog = false
    
    private var groupedEntries: [(String, [LogEntry])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let grouped = Dictionary(grouping: voyage.logEntries) { entry in
            dateFormatter.string(from: entry.timestamp)
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .none
        
        return grouped.sorted { $0.key > $1.key }
            .map { (key, entries) in
                if let date = dateFormatter.date(from: key) {
                    return (displayFormatter.string(from: date), entries)
                }
                return (key, entries)
            }
    }
    
    var body: some View {
        List {
            VoyageDetailsSection(voyage: voyage)
            
            ForEach(groupedEntries, id: \.0) { date, entries in
                ArchivedLogEntriesSection(
                    date: date,
                    entries: entries,
                    voyage: voyage,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore,
                    entryToDelete: $entryToDelete,
                    showingDeleteConfirmation: $showingDeleteConfirmation
                )
            }
        }
        .navigationTitle(voyage.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingVoyageLog = true
                } label: {
                    Image(systemName: "doc.text")
                }
            }
        }
        .confirmationDialog(
            "Delete Log Entry",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        voyageStore.deleteLogEntry(entry, fromVoyage: voyage)
                    }
                }
            },
            message: {
                Text("Are you sure you want to delete this log entry? This action cannot be undone.")
            }
        )
        .fullScreenCover(isPresented: $showingVoyageLog) {
            NavigationView {
                VoyageLogViewContainer(
                    voyage: voyage,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore,
                    voyageStore: voyageStore
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            showingVoyageLog = false
                        }
                    }
                }
            }
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

private struct VoyageDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
        }
        .padding(.vertical, 2)
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
                        .foregroundColor(.blue)
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
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f nm", entry.distance))
                            }
                        }
                        
                        if entry.magneticCourse > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .foregroundColor(.blue)
                                Text(String(format: "%.0f°", entry.magneticCourse))
                            }
                        }
                        
                        if entry.courseOverGround > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari.fill")
                                    .foregroundColor(.blue)
                                Text(String(format: "%.0f°", entry.courseOverGround))
                            }
                        }
                        
                        if entry.speed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .foregroundColor(.blue)
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