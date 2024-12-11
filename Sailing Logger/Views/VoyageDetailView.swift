import SwiftUI

struct VoyageDetailView: View {
    @State private var currentVoyage: Voyage
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @State private var showingEditSheet = false
    @State private var showingVoyageLog = false
    @Environment(\.dismiss) var dismiss
    @State private var showingEndVoyageAlert = false
    @State private var showingFilePicker = false
    @State private var importedVoyageData: Data?
    @State private var showingShareSheet = false
    @State private var exportData: Data?
    @State private var showingImportSuccessAlert = false
    @State private var importSuccessMessage = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isPreparingExport = false
    @Environment(\.colorScheme) var colorScheme
    
    init(voyage: Voyage, voyageStore: VoyageStore, locationManager: LocationManager, tileManager: OpenSeaMapTileManager, logStore: LogStore) {
        self.voyage = voyage
        self._currentVoyage = State(initialValue: voyage)
        self.voyageStore = voyageStore
        self.locationManager = locationManager
        self.tileManager = tileManager
        self.logStore = logStore
    }
    
    // Neue separate View für die Voyage Details Section
    private struct VoyageDetailsSection: View {
        let currentVoyage: Voyage
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            Section {
                VoyageDetailRow(
                    title: "Name", 
                    value: currentVoyage.name, 
                    icon: "tag.fill"
                )
                if !currentVoyage.boatName.isEmpty || !currentVoyage.boatType.isEmpty {
                    VoyageDetailRow(
                        title: "Boat", 
                        value: currentVoyage.boatType.isEmpty || currentVoyage.boatName.isEmpty ? 
                               currentVoyage.boatName + currentVoyage.boatType :
                               "\(currentVoyage.boatName) (\(currentVoyage.boatType))", 
                        icon: "sailboat.fill"
                    )
                }
                VoyageDetailRow(
                    title: "Start Date", 
                    value: currentVoyage.startDate.formatted(date: .long, time: .shortened), 
                    icon: "calendar"
                )
                if let endDate = currentVoyage.endDate {
                    VoyageDetailRow(
                        title: "End Date", 
                        value: endDate.formatted(date: .long, time: .shortened), 
                        icon: "calendar.badge.checkmark"
                    )
                }
            } header: {
                Label("Voyage Details", systemImage: "info.circle.fill")
                    .fontWeight(.bold)
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
        }
    }
    
    // Separate View für die Crew Section
    private struct CrewSection: View {
        let currentVoyage: Voyage
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            if !currentVoyage.crew.isEmpty {
                Section {
                    let sortedCrew = currentVoyage.crew.sorted { member1, member2 in
                        if member1.role == .skipper { return true }
                        if member2.role == .skipper { return false }
                        if member1.role == .secondSkipper { return true }
                        if member2.role == .secondSkipper { return false }
                        return false
                    }
                    
                    ForEach(sortedCrew) { crewMember in
                        crewDetailRow(for: crewMember)
                    }
                } header: {
                    Label("Crew", systemImage: "person.3.fill")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
        
        private func crewDetailRow(for crewMember: CrewMember) -> some View {
            let icon: String
            switch crewMember.role {
            case .skipper:
                icon = "sailboat.circle.fill"
            case .secondSkipper:
                icon = "sailboat.circle"
            default:
                icon = "person.fill"
            }
            
            let fontSize: CGFloat = (crewMember.role == .skipper || crewMember.role == .secondSkipper) ? 24 : 20
            
            return VoyageDetailRow(
                title: crewMember.role.rawValue,
                value: crewMember.name,
                icon: icon
            )
            .font(.system(size: fontSize))
        }
    }
    
    // Location Tracking Section
    private struct LocationTrackingSection: View {
        let voyage: Voyage
        @ObservedObject var voyageStore: VoyageStore
        @ObservedObject var locationManager: LocationManager
        @Environment(\.colorScheme) var colorScheme
        @State private var isTracking: Bool
        
        init(voyage: Voyage, voyageStore: VoyageStore, locationManager: LocationManager) {
            self.voyage = voyage
            self.voyageStore = voyageStore
            self.locationManager = locationManager
            self._isTracking = State(initialValue: voyage.isTracking)
        }
        
        var body: some View {
            if voyage.endDate == nil && UserDefaults.standard.bool(forKey: "AutoTrackingEnabled") {
                Section {
                    Toggle(isOn: $isTracking) {
                        HStack {
                            Image(systemName: isTracking ? "location.fill" : "location.slash.fill")
                            Text(isTracking ? "Tracking Active" : "Tracking Paused")
                        }
                    }
                    .tint(MaritimeColors.navy(for: colorScheme))
                    .onChange(of: isTracking) { _, newValue in
                        Task {
                            if let index = voyageStore.voyages.firstIndex(where: { $0.id == voyage.id }) {
                                voyageStore.voyages[index].isTracking = newValue
                                
                                if newValue {
                                    await MainActor.run {
                                        locationManager.startBackgroundTracking(interval: 10)
                                    }
                                } else {
                                    await MainActor.run {
                                        locationManager.stopBackgroundTracking()
                                    }
                                }
                                
                                voyageStore.save()
                            }
                        }
                    }
                    
                    if isTracking {
                        Text("Your position is being automatically logged. You can pause tracking anytime, for example when you're on shore or anchored for a longer period.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Location tracking is paused. Enable tracking when you're underway to automatically log your journey.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Location Tracking", systemImage: "location.fill")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
    }
    
    // Stats Section
    private struct StatsSection: View {
        let currentVoyage: Voyage
        @Environment(\.colorScheme) var colorScheme
        
        private func calculateMotorMiles() -> Double {
            let sortedEntries = currentVoyage.logEntries.sorted { $0.timestamp < $1.timestamp }
            var motorMiles = 0.0
            var lastDistance = 0.0
            
            for entry in sortedEntries {
                if entry.engineState == .on {
                    motorMiles += max(0, entry.distance - lastDistance)
                }
                lastDistance = entry.distance
            }
            
            return motorMiles
        }
        
        var body: some View {
            if currentVoyage.endDate != nil {
                Section {
                    if let maxDistance = currentVoyage.logEntries.map({ $0.distance }).max() {
                        VoyageDetailRow(
                            title: "Total Distance",
                            value: String(format: "%.1f nm", maxDistance),
                            icon: "arrow.triangle.swap"
                        )
                    }
                    
                    let motorMiles = calculateMotorMiles()
                    if motorMiles > 0 {
                        VoyageDetailRow(
                            title: "Motor Miles",
                            value: String(format: "%.1f nm", motorMiles),
                            icon: "engine.combustion"
                        )
                    }
                    
                    if let firstEntry = currentVoyage.logEntries.min(by: { $0.timestamp < $1.timestamp }),
                       let lastEntry = currentVoyage.logEntries.max(by: { $0.timestamp < $1.timestamp }),
                       let maxDistance = currentVoyage.logEntries.map({ $0.distance }).max() {
                        let duration = lastEntry.timestamp.timeIntervalSince(firstEntry.timestamp)
                        let averageSpeed = (maxDistance * 3600) / duration
                        VoyageDetailRow(
                            title: "Average Speed",
                            value: String(format: "%.1f kts", averageSpeed),
                            icon: "speedometer"
                        )
                    }
                    
                    if let maxSpeed = currentVoyage.logEntries.map({ $0.speed }).max() {
                        VoyageDetailRow(
                            title: "Max Speed",
                            value: String(format: "%.1f kts", maxSpeed),
                            icon: "speedometer"
                        )
                    }
                    
                    if let maxWind = currentVoyage.logEntries.map({ $0.wind.speedKnots }).max() {
                        VoyageDetailRow(
                            title: "Max Wind",
                            value: String(format: "%.1f kts", maxWind),
                            icon: "wind"
                        )
                    }
                    
                    VoyageDetailRow(
                        title: "Log Entries",
                        value: "\(currentVoyage.logEntries.count)",
                        icon: "list.bullet"
                    )
                } header: {
                    Label("Statistics", systemImage: "chart.bar.fill")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
    }
    
    // Log Entries Section
    private struct LogEntriesSection: View {
        let currentVoyage: Voyage
        @ObservedObject var voyageStore: VoyageStore
        @ObservedObject var locationManager: LocationManager
        @ObservedObject var tileManager: OpenSeaMapTileManager
        @ObservedObject var logStore: LogStore
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            if currentVoyage.endDate != nil {
                Section {
                    ForEach(currentVoyage.logEntries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
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
                            LogEntryRow(entry: entry)
                        }
                    }
                } header: {
                    Label("Log Entries", systemImage: "list.bullet")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
    }
    
    // Import/Export Section
    private struct ImportExportSection: View {
        let currentVoyage: Voyage
        @Binding var showingFilePicker: Bool
        @Binding var isPreparingExport: Bool
        @Environment(\.colorScheme) var colorScheme
        let importAction: () -> Void
        let exportAction: () -> Void
        
        var body: some View {
            if currentVoyage.endDate == nil {
                Section {
                    HStack(spacing: 0) {
                        Button(action: importAction) {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                .padding(.vertical, 8)
                        }
                        .disabled(isPreparingExport)
                        
                        Divider()
                        
                        Button(action: exportAction) {
                            if isPreparingExport {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Preparing...")
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                .padding(.vertical, 8)
                            } else {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                    .padding(.vertical, 8)
                            }
                        }
                        .disabled(isPreparingExport)
                    }
                } header: {
                    Label("Voyage Sync", systemImage: "arrow.triangle.2.circlepath")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        .padding(.leading)
                } footer: {
                    Text("Export your voyage data to share with crew members or import data from others to sync log entries between devices.")
                        .foregroundColor(.secondary)
                        .padding(.leading)
                        .padding(.top, 8)
                }
                .listRowInsets(EdgeInsets())
                .buttonStyle(.plain)
            }
        }
    }
    
    // End Voyage Section
    private struct EndVoyageSection: View {
        let currentVoyage: Voyage
        @Binding var showingEndVoyageAlert: Bool
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            if currentVoyage.endDate == nil {
                Section {
                    SlideToEndButton(
                        text: "Slide to End Voyage",
                        action: {
                            showingEndVoyageAlert = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Label("End Voyage", systemImage: "flag.checkered")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                } footer: {
                    Text("Once a voyage is ended, it will be moved to the archive. Log entries of archived voyages cannot be modified anymore")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
    }
    
    var body: some View {
        List {
            VoyageDetailsSection(currentVoyage: currentVoyage)
            CrewSection(currentVoyage: currentVoyage)
            LocationTrackingSection(
                voyage: voyage,
                voyageStore: voyageStore,
                locationManager: locationManager
            )
            StatsSection(currentVoyage: currentVoyage)
            LogEntriesSection(
                currentVoyage: currentVoyage,
                voyageStore: voyageStore,
                locationManager: locationManager,
                tileManager: tileManager,
                logStore: logStore
            )
            ImportExportSection(
                currentVoyage: currentVoyage,
                showingFilePicker: $showingFilePicker,
                isPreparingExport: $isPreparingExport,
                importAction: importVoyageData,
                exportAction: exportVoyageData
            )
            EndVoyageSection(
                currentVoyage: currentVoyage,
                showingEndVoyageAlert: $showingEndVoyageAlert
            )
        }
        .navigationTitle(currentVoyage.name)
        .detailToolbar(
            showEdit: { showingEditSheet = true },
            showLog: { showingVoyageLog = true }
        )
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                EditVoyageView(
                    voyageStore: voyageStore,
                    voyage: currentVoyage
                )
            }
        }
        .fullScreenCover(isPresented: $showingVoyageLog) {
            NavigationView {
                VoyageLogViewContainer(
                    voyage: currentVoyage,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore,
                    voyageStore: voyageStore
                )
                .logViewToolbar(dismiss: { showingVoyageLog = false })
            }
        }
        .alert("End Voyage?", isPresented: $showingEndVoyageAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Voyage", role: .destructive) {
                endVoyage()
            }
        } message: {
            Text("Once a voyage is ended, no further modifications to the logs will be possible. This action cannot be undone.")
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker { data in
                handleImportedData(data)
            }
        }
        .alert("Import Successful", isPresented: $showingImportSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(importSuccessMessage)
        }
        .onChange(of: currentVoyage.logEntries) { oldValue, newValue in
            print("🔄 View updating with new log entries")
            print("   Old count: \(oldValue.count)")
            print("   New count: \(newValue.count)")
        }
    }
    
    private func endVoyage() {
        let updatedVoyage = currentVoyage
        updatedVoyage.endDate = Date()
        if let index = voyageStore.voyages.firstIndex(where: { $0.id == currentVoyage.id }) {
            voyageStore.voyages[index] = updatedVoyage
            dismiss()
            voyageStore.resetActiveVoyageIfCompleted()
        }
    }
    
    private func importVoyageData() {
        print("📥 Opening file picker for import...")
        showingFilePicker = true
    }
    
    private func handleImportedData(_ data: Data) {
        do {
            print("📥 Starting to decode imported data...")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601  // Wichtig: Gleiche Strategie wie beim Export
            
            // Debug: Zeige den importierten JSON-String
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 Imported JSON:")
                print(jsonString)
            }
            
            let importedVoyage = try decoder.decode(Voyage.self, from: data)
            
            // Prüfe ob es die gleiche Voyage ist
            guard importedVoyage.id == voyage.id else {
                alertMessage = "The imported data belongs to a different voyage (ID mismatch)"
                showAlert = true
                print("❌ Imported voyage ID (\(importedVoyage.id)) doesn't match current voyage ID (\(voyage.id))")
                return
            }
            
            print("📥 Found matching voyage with \(importedVoyage.logEntries.count) entries")
            print("📥 Current voyage has \(currentVoyage.logEntries.count) entries")
            
            // Merge Logeinträge
            var updatedLogEntries = currentVoyage.logEntries
            var importedCount = 0
            var updatedCount = 0
            
            for importedEntry in importedVoyage.logEntries {
                print("📥 Checking imported entry with ID: \(importedEntry.id)")
                
                if let existingIndex = updatedLogEntries.firstIndex(where: { $0.id == importedEntry.id }) {
                    print("   Found existing entry")
                    if shouldUpdateEntry(existing: updatedLogEntries[existingIndex], imported: importedEntry) {
                        print("   ✅ Updating existing entry")
                        updatedLogEntries[existingIndex] = importedEntry
                        updatedCount += 1
                    }
                } else {
                    print("   ✨ Adding new entry")
                    updatedLogEntries.append(importedEntry)
                    importedCount += 1
                }
            }
            
            // Update die Voyage im VoyageStore
            if let index = voyageStore.voyages.firstIndex(where: { $0.id == voyage.id }) {
                if importedCount > 0 || updatedCount > 0 {
                    print("📥 Updating voyage in store with \(updatedLogEntries.count) total entries")
                    voyageStore.voyages[index].logEntries = updatedLogEntries
                    
                    // Aktualisiere auch die currentVoyage
                    currentVoyage = voyageStore.voyages[index]
                    
                    voyageStore.save()
                    
                    // Aktualisiere auch den LogStore
                    logStore.importEntries(updatedLogEntries)
                    
                    importSuccessMessage = "Successfully imported \(importedCount) new and updated \(updatedCount) existing entries."
                } else {
                    importSuccessMessage = "No new entries found. Your local data is already up to date."
                }
                
                showingImportSuccessAlert = true
                print("✅ Import successful")
            }
            
        } catch {
            print("❌ Error decoding voyage data: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: \(type), at path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            alertMessage = "Could not import data: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func shouldUpdateEntry(existing: LogEntry, imported: LogEntry) -> Bool {
        // Prüfe ob der importierte Eintrag neuer ist
        if imported.timestamp > existing.timestamp {
            return true
        }
        
        // Prüfe ob der importierte Eintrag vollständiger ist
        let existingNilCount = countNilValues(in: existing)
        let importedNilCount = countNilValues(in: imported)
        
        return importedNilCount < existingNilCount
    }
    
    private func countNilValues(in entry: LogEntry) -> Int {
        var nilCount = 0
        
        if entry.notes == nil { nilCount += 1 }
        if entry.maneuver == nil { nilCount += 1 }
        if entry.courseOverGround == 0 { nilCount += 1 }
        if entry.magneticCourse == 0 { nilCount += 1 }
        if entry.speed == 0 { nilCount += 1 }
        if entry.wind.speedKnots == 0 { nilCount += 1 }
        if entry.barometer == 1013.25 { nilCount += 1 }  // Default-Wert
        if entry.temperature == 0 { nilCount += 1 }
        if entry.visibility == 0 { nilCount += 1 }
        if entry.cloudCover == 0 { nilCount += 1 }
        
        return nilCount
    }
    
    private func prepareFileForExport() async throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(currentVoyage)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "voyage_export_\(UUID().uuidString).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try data.write(to: fileURL, options: .atomic)
        
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let _ = try? Data(contentsOf: fileURL) else {
            throw NSError(domain: "", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "File verification failed"])
        }
        
        try (fileURL as NSURL).setResourceValue(true, forKey: .isReadableKey)
        
        return fileURL
    }
    
    private func exportVoyageData() {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                
                let data = try encoder.encode(currentVoyage)
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "voyage_export_\(UUID().uuidString).json"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try data.write(to: fileURL, options: .atomic)
                
                await MainActor.run {
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let view = windowScene.windows.first?.rootViewController?.view {
                        SharePresenter.present(url: fileURL, from: view)
                    }
                    self.isPreparingExport = false
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Export failed: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isPreparingExport = false
                }
            }
        }
    }
}

// Neue Helper-Klasse für die Präsentation
class SharePresenter: NSObject {
    static func present(url: URL, from view: UIView) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Verwende die neue API für iOS 15+
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
} 
