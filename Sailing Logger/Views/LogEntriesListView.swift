import SwiftUI

struct LogEntriesListView: View {
    @ObservedObject var logStore: LogStore
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @State private var showingDeleteConfirmation = false
    @State private var entryToDelete: LogEntry?
    
    private var groupedEntries: [(String, [LogEntry])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let grouped = Dictionary(grouping: logStore.entries) { entry in
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
            ForEach(groupedEntries, id: \.0) { date, entries in
                LogEntriesSection(
                    date: date,
                    entries: entries,
                    logStore: logStore,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    entryToDelete: $entryToDelete,
                    showingDeleteConfirmation: $showingDeleteConfirmation
                )
            }
        }
        .frame(maxWidth: .infinity)
        .scrollContentBackground(.hidden)
        .listStyle(PlainListStyle())
        .confirmationDialog(
            "Delete Entry",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        logStore.deleteEntry(entry)
                    }
                }
            },
            message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
        )
    }
}

struct LogEntriesSection: View {
    let date: String
    let entries: [LogEntry]
    let logStore: LogStore
    let voyageStore: VoyageStore
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    @Binding var entryToDelete: LogEntry?
    @Binding var showingDeleteConfirmation: Bool
    
    var body: some View {
        Section {
            ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                NavigationLink(destination: LogEntryDetailView(
                    entry: entry,
                    isArchived: false,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore
                )) {
                    LogEntryRow(entry: entry)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    entryToDelete = entries[index]
                    showingDeleteConfirmation = true
                }
            }
        } header: {
            HStack {
                Text(date)
                    .font(.headline)
                    .foregroundColor(.black)
                    .textCase(nil)
                    .padding(.top, 10)
                Spacer()
                NavigationLink(destination: DailyLogViewContainer(entries: entries, date: date)) {
                    Image(systemName: "doc.text")
                        .foregroundColor(MaritimeColors.navy)
                }
            }
        }
    }
}
