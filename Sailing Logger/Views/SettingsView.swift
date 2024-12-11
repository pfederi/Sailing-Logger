import SwiftUI
import MapKit
import UniformTypeIdentifiers

enum TrackingInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .tenMinutes: return "10 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        }
    }
    
    static func fromRawValue(_ value: Int) -> TrackingInterval {
        return TrackingInterval.allCases.first { $0.rawValue == value } ?? .fiveMinutes
    }
}

class TrackingSettings: ObservableObject {
    @Published var isAutoTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoTrackingEnabled, forKey: "AutoTrackingEnabled")
        }
    }
    
    @Published var trackingInterval: TrackingInterval {
        didSet {
            UserDefaults.standard.set(trackingInterval.rawValue, forKey: "TrackingInterval")
        }
    }
    
    init() {
        self.isAutoTrackingEnabled = UserDefaults.standard.bool(forKey: "AutoTrackingEnabled")
        let rawValue = UserDefaults.standard.integer(forKey: "TrackingInterval")
        self.trackingInterval = TrackingInterval.fromRawValue(rawValue)
    }
}

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var logStore: LogStore
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var regionToDelete: String?
    @State private var showDownloadStartedAlert = false
    @Environment(\.colorScheme) var systemColorScheme  // System color scheme
    @State private var forceUpdate = UUID()  // Neuer State für Force Update
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            SettingsFormContent(
                themeManager: themeManager,
                logStore: logStore,
                tileManager: tileManager,
                voyageStore: voyageStore,
                locationManager: locationManager,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                regionToDelete: $regionToDelete,
                showDownloadStartedAlert: $showDownloadStartedAlert,
                dismiss: dismiss
            )
        }
        .overlay {
            if showingSuccessAlert {
                SuccessOverlay(
                    message: successMessage,
                    showingSuccessAlert: $showingSuccessAlert,
                    dismiss: dismiss
                )
            }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(themeManager.storedColorScheme == "system" ? systemColorScheme : themeManager.colorScheme)
        .onChange(of: themeManager.storedColorScheme) { oldValue, newValue in
            if newValue == "system" {
                forceUpdate = UUID()
            }
            withAnimation {
                themeManager.updateColorScheme()
            }
        }
        .onChange(of: systemColorScheme) { oldValue, newValue in
            if themeManager.storedColorScheme == "system" {
                forceUpdate = UUID()
            }
        }
        .id(forceUpdate)
        .alert("Map Download Started", isPresented: $showDownloadStartedAlert) {
            Button("Continue Using App") {
                dismiss()
                tileManager.showDownloadStartedAlert = false
            }
            Button("Stay Here") {
                tileManager.showDownloadStartedAlert = false
            }
        } message: {
            Text("The map download has started in the background. You can continue using the app or even close it - you'll receive a notification when the download is complete.")
        }
        .onReceive(tileManager.$showDownloadStartedAlert) { show in
            showDownloadStartedAlert = show
        }
        .onDisappear {
            tileManager.showDownloadStartedAlert = false
        }
    }
}

private struct SettingsFormContent: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var logStore: LogStore
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @Binding var showingDeleteConfirmation: Bool
    @Binding var regionToDelete: String?
    @Binding var showDownloadStartedAlert: Bool
    let dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var trackingSettings = TrackingSettings()
    
    var body: some View {
        Form {
            AppearanceSection(themeManager: themeManager)
            locationTrackingSection
            WeatherSection(themeManager: themeManager)
            OpenSeaMapSection(
                tileManager: tileManager,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                regionToDelete: $regionToDelete
            )
            DataManagementSection(logStore: logStore, voyageStore: voyageStore)
            AboutSection()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .tint(MaritimeColors.navy(for: colorScheme))
    }
    
    private var locationTrackingSection: some View {
        Section("Location Tracking") {
            Toggle("Auto-track Distance", isOn: $trackingSettings.isAutoTrackingEnabled)
                .onChange(of: trackingSettings.isAutoTrackingEnabled) { _, newValue in
                    if newValue {
                        locationManager.startBackgroundTracking(interval: trackingSettings.trackingInterval.rawValue)
                    } else {
                        locationManager.stopBackgroundTracking()
                    }
                }
            
            if trackingSettings.isAutoTrackingEnabled {
                Picker("Update Interval", selection: $trackingSettings.trackingInterval) {
                    ForEach(TrackingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .onChange(of: trackingSettings.trackingInterval) { _, newValue in
                    if trackingSettings.isAutoTrackingEnabled {
                        locationManager.startBackgroundTracking(interval: newValue.rawValue)
                    }
                }
            }
            
            Text("Background location tracking is needed to automatically calculate distances between log entries and provide current speed data. All location data remains on your device and is not shared with any third parties.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

private struct SuccessOverlay: View {
    let message: String
    @Binding var showingSuccessAlert: Bool
    let dismiss: DismissAction
    
    var body: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack {
                    Text("Import Successful")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("OK") {
                        showingSuccessAlert = false
                        dismiss()
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(40)
            }
    }
}

private struct OpenSeaMapSection: View {
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Binding var showingDeleteConfirmation: Bool
    @Binding var regionToDelete: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Section("OpenSeaMap Tiles") {
            RegionsList(
                tileManager: tileManager,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                regionToDelete: $regionToDelete
            )
            
            Link("Not sure which map to download? Find information about map coverage here",
                 destination: URL(string: "https://wiki.openstreetmap.org/wiki/MBTiles")!)
                .font(.caption)
                .foregroundColor(MaritimeColors.navy(for: colorScheme))
        }
        .alert(
            "Delete Map",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Cancel", role: .cancel) { }
                if let region = regionToDelete {
                    Button("Delete \(region.capitalized)", role: .destructive) {
                        tileManager.deleteTiles(for: region)
                    }
                }
            },
            message: {
                if let region = regionToDelete {
                    Text("Are you sure you want to delete the map for \(region.capitalized)?")
                }
            }
        )
    }
    
    private func showDeleteConfirmation(for region: String) {
        regionToDelete = region
        showingDeleteConfirmation = true
    }
}

private struct RegionsList: View {
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Binding var showingDeleteConfirmation: Bool
    @Binding var regionToDelete: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ForEach(tileManager.availableRegions, id: \.self) { region in
            RegionRow(
                region: region,
                tileManager: tileManager,
                showDeleteConfirmation: showDeleteConfirmation(for:)
            )
        }
        .onDelete { indexSet in
            for index in indexSet {
                let region = tileManager.availableRegions[index]
                if tileManager.isFileDownloaded(region) {
                    showDeleteConfirmation(for: region)
                }
            }
        }
    }
    
    private func showDeleteConfirmation(for region: String) {
        regionToDelete = region
        showingDeleteConfirmation = true
    }
}

private struct RegionRow: View {
    let region: String
    @ObservedObject var tileManager: OpenSeaMapTileManager
    let showDeleteConfirmation: (String) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(region.capitalized)
            Spacer()
            if tileManager.isPreparing && region == tileManager.currentlyDownloading {
                PreparingDownloadView()
            } else if tileManager.isDownloading {
                DownloadingView(region: region, tileManager: tileManager)
            } else {
                DownloadStatusView(region: region, tileManager: tileManager)
            }
        }
    }
}

private struct PreparingDownloadView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text("Preparing download...")
            .font(.caption)
            .foregroundColor(MaritimeColors.navy(for: colorScheme))
    }
}

private struct DownloadingView: View {
    let region: String
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if region == tileManager.currentlyDownloading {
                DownloadProgressView(tileManager: tileManager)
            } else if tileManager.isFileDownloaded(region) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
        }
    }
}

private struct DownloadProgressView: View {
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .trailing) {
            ProgressView(value: tileManager.downloadProgress)
                .progressViewStyle(.linear)
                .frame(width: 100)
            HStack {
                Text("\(ByteCountFormatter.string(fromByteCount: tileManager.downloadedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: tileManager.totalBytes, countStyle: .file))")
                if let timeRemaining = tileManager.estimatedTimeRemaining {
                    Text("(\(Int(timeRemaining))s remaining)")
                }
            }
            .font(.caption)
            
            Button("Cancel") {
                tileManager.cancelDownload()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
}

private struct DownloadStatusView: View {
    let region: String
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if tileManager.isFileDownloaded(region) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    Task {
                        try? await tileManager.downloadTiles(for: region)
                    }
                }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
    }
}

private struct AppearanceSection: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeManager.storedColorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
    }
}

private struct WeatherSection: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        Section("OpenWeather API") {
            SecureField("API Key", text: $themeManager.openWeatherApiKey)
            Link("Get your free API key at openweathermap.org",
                 destination: URL(string: "https://openweathermap.org/api")!)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

private struct DataManagementSection: View {
    @ObservedObject var logStore: LogStore
    @ObservedObject var voyageStore: VoyageStore
    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreAlert = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportError = false
    @State private var showingDeletedFeedback = false
    @State private var importErrorMessage = ""
    @State private var isProcessing = false
    @State private var showingBackupSuccessAlert = false
    @State private var showingImportSuccessAlert = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Section("Data Management") {
            // Backup Button
            Button {
                createBackup()
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise.icloud")
                    }
                    Text(isProcessing ? "Creating Backup..." : "Create Backup")
                }
            }
            .disabled(isProcessing)
            
            // Restore Button
            Button {
                showingRestoreAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.icloud")
                    Text("Restore from Backup")
                }
            }
            .disabled(isProcessing)
            
            // Delete All Data Button
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Data")
                }
            }
            .disabled(isProcessing)
        }
        .alert("Restore from Backup", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Choose Backup File") {
                showingImporter = true
            }
        } message: {
            Text("This will replace all current data with the data from the backup file. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: BackupDocument(voyages: voyageStore.voyages, entries: logStore.entries),
            contentType: .json,
            defaultFilename: "sailing-log-backup-\(Date().ISO8601Format()).json"
        ) { result in
            switch result {
            case .success(_):
                showingBackupSuccessAlert = true
            case .failure(let error):
                importErrorMessage = "Backup failed: \(error.localizedDescription)"
                showingImportError = true
            }
            isProcessing = false
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            isProcessing = true
            print("\n=== Starting Import Process ===")
            
            Task {
                do {
                    let url = try result.get()
                    print("📥 Selected file URL: \(url.absoluteString)")
                    
                    guard url.startAccessingSecurityScopedResource() else {
                        print("❌ Security access denied for URL")
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let data = try Data(contentsOf: url)
                    print("📥 Read \(data.count) bytes from file")
                    
                    // Validate JSON structure
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("❌ Failed to parse JSON structure")
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
                    }
                    
                    print("\n🔍 Validating JSON structure:")
                    print("Found keys: \(jsonObject.keys.sorted().joined(separator: ", "))")
                    
                    // Validate entries
                    if let entries = jsonObject["entries"] as? [[String: Any]] {
                        print("\n📝 Entries validation:")
                        print("- Found \(entries.count) entries")
                        if let firstEntry = entries.first {
                            print("- First entry keys: \(firstEntry.keys.sorted().joined(separator: ", "))")
                        }
                    } else {
                        print("❌ Invalid entries format")
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid entries format"])
                    }
                    
                    // Validate voyages
                    if let voyages = jsonObject["voyages"] as? [[String: Any]] {
                        print("\n🚢 Voyages validation:")
                        print("- Found \(voyages.count) voyages")
                        if let firstVoyage = voyages.first {
                            print("- First voyage keys: \(firstVoyage.keys.sorted().joined(separator: ", "))")
                            
                            // Check for active voyages
                            let activeVoyages = voyages.filter { ($0["isActive"] as? Bool) == true }
                            print("- Active voyages found: \(activeVoyages.count)")
                            
                            // Check for voyage dates
                            if let startDate = firstVoyage["startDate"] as? String {
                                print("- Start date format: \(startDate)")
                            }
                        }
                    } else {
                        print("❌ Invalid voyages format")
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid voyages format"])
                    }
                    
                    print("\n📅 Backup metadata:")
                    if let backupDate = jsonObject["backupDate"] as? String {
                        print("- Backup date: \(backupDate)")
                    }
                    if let appVersion = jsonObject["appVersion"] as? String {
                        print("- App version: \(appVersion)")
                    }
                    
                    print("\n🔄 Attempting to decode backup data...")
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601  // Wichtig für ISO8601 Datumsstrings
                    
                    let backup = try decoder.decode(BackupData.self, from: data)
                    print("✅ Successfully decoded backup data:")
                    print("- Total voyages: \(backup.voyages.count)")
                    print("- Total entries: \(backup.entries.count)")
                    print("- Backup date: \(backup.backupDate)")
                    print("- App version: \(backup.appVersion)")
                    
                    // Additional validation
                    let duplicateVoyageIds = findDuplicates(in: backup.voyages.map { $0.id })
                    let duplicateEntryIds = findDuplicates(in: backup.entries.map { $0.id })
                    
                    if !duplicateVoyageIds.isEmpty {
                        print("⚠️ Warning: Found duplicate voyage IDs: \(duplicateVoyageIds)")
                    }
                    if !duplicateEntryIds.isEmpty {
                        print("⚠️ Warning: Found duplicate entry IDs: \(duplicateEntryIds)")
                    }
                    
                    // Restore data
                    await MainActor.run {
                        print("\n💾 Starting data restoration...")
                        voyageStore.restoreFromBackup(backup.voyages)
                        logStore.restoreFromBackup(backup.entries)
                        print("✅ Data restoration completed")
                        showingImportSuccessAlert = true
                    }
                } catch {
                    print("\n❌ Import error: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("🔍 Decoding error details:")
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   Data corrupted: \(context.debugDescription)")
                            print("   Coding path: \(context.codingPath)")
                        case .keyNotFound(let key, let context):
                            print("   Key '\(key.stringValue)' not found")
                            print("   Coding path: \(context.codingPath)")
                        case .typeMismatch(let type, let context):
                            print("   Type mismatch: expected \(type)")
                            print("   Coding path: \(context.codingPath)")
                            print("   Debug description: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   Value of type \(type) not found")
                            print("   Coding path: \(context.codingPath)")
                        @unknown default:
                            print("   Unknown decoding error")
                        }
                    }
                    await MainActor.run {
                        importErrorMessage = "Could not read backup file: \(error.localizedDescription)\n\nPlease make sure you're selecting a valid backup file created by this app."
                        showingImportError = true
                    }
                }
                isProcessing = false
                print("\n=== Import Process Completed ===\n")
            }
        }
        .confirmationDialog(
            "Delete All Data",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete All", role: .destructive) {
                    logStore.deleteAllEntries()
                    voyageStore.deleteAllData()
                    showingDeletedFeedback = true
                }
            },
            message: {
                Text("Are you sure you want to delete all voyages and log entries? This action cannot be undone.")
            }
        )
        .alert("Import Successful", isPresented: $showingImportSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
            .foregroundColor(MaritimeColors.navy(for: colorScheme))
        } message: {
            Text("Data restored successfully")
        }
        .alert("Backup Successful", isPresented: $showingBackupSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
            .foregroundColor(MaritimeColors.navy(for: colorScheme))
        } message: {
            Text("Your data has been backed up successfully")
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
            .foregroundColor(MaritimeColors.navy(for: colorScheme))
        } message: {
            Text(importErrorMessage)
        }
        .alert("Data Deleted", isPresented: $showingDeletedFeedback) {
            Button("OK", role: .cancel) { }
            .foregroundColor(MaritimeColors.navy(for: colorScheme))
        } message: {
            Text("All voyages and log entries have been successfully deleted.")
        }
    }
    
    private func createBackup() {
        isProcessing = true
        showingExporter = true
    }
    
    // Helper function to find duplicates
    private func findDuplicates(in array: [UUID]) -> [String] {
        var seen = Set<UUID>()
        var duplicates = Set<UUID>()
        for item in array {
            if !seen.insert(item).inserted {
                duplicates.insert(item)
            }
        }
        return Array(duplicates).map { $0.uuidString }
    }
}

private struct AboutSection: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "Version \(version)"
    }
    
    var body: some View {
        Section {
            VStack(spacing: 8) {
                Text(appVersion)
                    .font(.footnote)
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                
                Text("Created with ❤️ in Zurich with the sea in our heart. May you always have wind in your sails and a hand-width of water under your keel!")
                    .font(.footnote)
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
    }
}

struct SeaRegion: Identifiable {
    let id: String
    let name: String
    let url: String
    let size: String
}

struct BackupData: Codable {
    let voyages: [Voyage]
    let entries: [LogEntry]
    let backupDate: Date
    let appVersion: String
    
    init(voyages: [Voyage], entries: [LogEntry]) {
        self.voyages = voyages
        self.entries = entries
        self.backupDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let backup: BackupData
    
    init(voyages: [Voyage], entries: [LogEntry]) {
        self.backup = BackupData(voyages: voyages, entries: entries)
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}
