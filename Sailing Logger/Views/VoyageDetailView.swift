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
    
    init(voyage: Voyage, voyageStore: VoyageStore, locationManager: LocationManager, tileManager: OpenSeaMapTileManager, logStore: LogStore) {
        self.voyage = voyage
        self._currentVoyage = State(initialValue: voyage)
        self.voyageStore = voyageStore
        self.locationManager = locationManager
        self.tileManager = tileManager
        self.logStore = logStore
    }
    
    private func crewDetailRow(for crewMember: CrewMember) -> some View {
        let icon = crewMember.role == .skipper ? "sailboat.circle.fill" :
                  crewMember.role == .secondSkipper ? "sailboat.circle" :
                  "person.fill"
        
        return VoyageDetailRow(
            title: crewMember.role.rawValue,
            value: crewMember.name,
            icon: icon
        )
        .font(.system(size: crewMember.role == .skipper || crewMember.role == .secondSkipper ? 24 : 20))
    }
    
    var body: some View {
        List {
            // Voyage Details Section
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
                VoyageDetailRow(title: "Start Date", value: currentVoyage.startDate.formatted(date: .long, time: .shortened), icon: "calendar")
                if let endDate = currentVoyage.endDate {
                    VoyageDetailRow(title: "End Date", value: endDate.formatted(date: .long, time: .shortened), icon: "calendar.badge.checkmark")
                }
            } header: {
                Label("Voyage Details", systemImage: "info.circle.fill")
                    .fontWeight(.bold)
                    .foregroundColor(MaritimeColors.navy)
            }
            // Crew Section
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
                    .foregroundColor(MaritimeColors.navy)
                }
            }
            // Stats Section
            if !currentVoyage.logEntries.isEmpty {
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
                        let averageSpeed = (maxDistance * 3600) / duration  // nm/h = knots
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
                        .foregroundColor(MaritimeColors.navy)
                }
            }

            // Log Entries Section - nur für archivierte Voyages
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
                        .foregroundColor(MaritimeColors.navy)
                }
            }

            // Import/Export Section
            if currentVoyage.endDate == nil {
                Section {
                    HStack(spacing: 0) {
                        Button(action: { importVoyageData() }) {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(MaritimeColors.navy)
                                .padding(.vertical, 8)
                        }
                        
                        Divider()
                        
                        Button(action: { exportVoyageData() }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(MaritimeColors.navy)
                                .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Label("Voyage Sync", systemImage: "arrow.triangle.2.circlepath")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy)
                        .padding(.horizontal, 16)
                } footer: {
                    Text("Export your voyage data to share with crew members or import data from others to sync log entries between devices.")
                        .foregroundColor(MaritimeColors.navy)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .listRowInsets(EdgeInsets())
                .buttonStyle(.plain)
            }

            // End Voyage Button Section
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
                        .foregroundColor(MaritimeColors.navy)
                } footer: {
                    Text("Once a voyage is ended, it will be moved to the archive. Log entries of archived voyages cannot be modified anymore.")
                        .foregroundColor(MaritimeColors.navy)
                        .padding(.top, 8)
                }
            }
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
        .sheet(isPresented: $showingShareSheet) {
            if let tempFileURL = exportData.flatMap({ data -> URL? in
                let safeVoyageName = currentVoyage.name
                    .replacingOccurrences(of: " ", with: "_")
                    .components(separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").inverted)
                    .joined()
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(safeVoyageName)_voyage_\(currentVoyage.id).json")
                try? data.write(to: url)
                return url
            }) {
                ShareSheet(items: [tempFileURL])
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
            let importedVoyage = try decoder.decode(Voyage.self, from: data)
            
            // Prüfe ob es die gleiche Voyage ist
            guard importedVoyage.id == voyage.id else {
                print("❌ Imported voyage ID doesn't match")
                return
            }
            
            print("📥 Found matching voyage with \(importedVoyage.logEntries.count) entries")
            print("📥 Current voyage has \(voyage.logEntries.count) entries")
            
            // Merge Logeinträge
            var updatedLogEntries = currentVoyage.logEntries
            var importedCount = 0
            var updatedCount = 0
            
            for importedEntry in importedVoyage.logEntries {
                print("📥 Checking imported entry with ID: \(importedEntry.id)")
                
                if let existingIndex = updatedLogEntries.firstIndex(where: { $0.id == importedEntry.id }) {
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
                    voyageStore.voyages[index].logEntries = updatedLogEntries
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
    
    private func exportVoyageData() {
        do {
            print("📤 Starting export for voyage: \(currentVoyage.name)")
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentVoyage)
            
            // Erstelle einen sicheren Dateinamen aus dem Voyage-Namen
            let safeVoyageName = currentVoyage.name
                .replacingOccurrences(of: " ", with: "_") // Ersetze Leerzeichen mit Unterstrichen
                .components(separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").inverted)
                .joined() // Entferne alle nicht erlaubten Zeichen
            
            print("📤 Safe voyage name: \(safeVoyageName)")
            
            // Erstelle eine temporäre Datei mit dem Voyage-Namen
            let tempFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeVoyageName)_voyage_\(currentVoyage.id).json")
            
            print("📤 Saving to: \(tempFileURL.path)")
            
            try data.write(to: tempFileURL)
            exportData = data
            
            // Zeige Share Sheet
            showingShareSheet = true
            print("📤 Export prepared successfully")
        } catch {
            print("❌ Error preparing voyage data for export: \(error)")
        }
    }
} 