import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var logStore: LogStore
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var regionToDelete: String?
    @State private var showDownloadStartedAlert = false
    @Environment(\.colorScheme) var systemColorScheme  // System color scheme
    @State private var forceUpdate = UUID()  // Neuer State für Force Update
    
    private func showDeleteConfirmation(for region: String) {
        regionToDelete = region
        showingDeleteConfirmation = true
    }
    
    var body: some View {
        NavigationView {
            Form {
                AppearanceSection(themeManager: themeManager)
                
                WeatherSection(themeManager: themeManager)
                
                Section("OpenSeaMap Tiles") {
                    ForEach(tileManager.availableRegions, id: \.self) { region in
                        HStack {
                            Text(region.capitalized)
                            Spacer()
                            if tileManager.isPreparing && region == tileManager.currentlyDownloading {
                                Text("Preparing download...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if tileManager.isDownloading {
                                if region == tileManager.currentlyDownloading {
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
                                } else if tileManager.isFileDownloaded(region) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.gray)
                                }
                            } else {
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
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let region = tileManager.availableRegions[index]
                            if tileManager.isFileDownloaded(region) {
                                showDeleteConfirmation(for: region)
                            }
                        }
                    }
                    
                    Link("Not sure which map to download? Find information about map coverage here",
                         destination: URL(string: "https://wiki.openstreetmap.org/wiki/MBTiles")!)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .confirmationDialog(
                    "Delete Map",
                    isPresented: $showingDeleteConfirmation,
                    presenting: regionToDelete
                ) { region in
                    Button("Delete \(region.capitalized)", role: .destructive) {
                        tileManager.deleteTiles(for: region)
                    }
                } message: { region in
                    Text("Are you sure you want to delete the map for \(region.capitalized)?")
                }
                
                DataManagementSection(logStore: logStore)
                
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
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(themeManager.storedColorScheme == "system" ? systemColorScheme : themeManager.colorScheme)
        .onChange(of: themeManager.storedColorScheme) { oldValue, newValue in
            if newValue == "system" {
                // Erzwinge komplette Neuzeichnung der View
                forceUpdate = UUID()
            }
            withAnimation {
                themeManager.updateColorScheme()
            }
        }
        .onChange(of: systemColorScheme) { oldValue, newValue in
            if themeManager.storedColorScheme == "system" {
                // Erzwinge komplette Neuzeichnung der View
                forceUpdate = UUID()
            }
        }
        .id(forceUpdate)  // View wird komplett neu erstellt wenn UUID sich ändert
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
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletedFeedback = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var isImporting = false
    @State private var showingImportSuccess = false
    
    var body: some View {
        Section("Data Management") {
            Button {
                showingExporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export All Log Entries")
                }
            }
            .disabled(isImporting)
            
            Button {
                showingImporter = true
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isImporting ? "Importing..." : "Import Log Entries")
                }
            }
            .disabled(isImporting)
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Log Entries")
                }
            }
            .disabled(isImporting)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: LogEntriesDocument(entries: Array(logStore.entries)),
            contentType: .json,
            defaultFilename: "sailing-log-\(Date().ISO8601Format()).json"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print("Error saving file: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            isImporting = true
            
            Task {
                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access file"])
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    
                    // Konfiguriere den Decoder für fehlende Werte
                    decoder.keyDecodingStrategy = .useDefaultKeys
                    decoder.dateDecodingStrategy = .iso8601
                    
                    // Setze die Standardwerte für fehlende Felder
                    let entries = try decoder.decode([LogEntry].self, from: data)
                    
                    await MainActor.run {
                        logStore.importEntries(entries)
                        isImporting = false
                        showingImportSuccess = true
                    }
                } catch {
                    await MainActor.run {
                        print("Import error details: \(error)")  // Detailed debug output
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                importErrorMessage = "Data corrupted: \(context.debugDescription)"
                            case .keyNotFound(let key, let context):
                                importErrorMessage = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
                            case .typeMismatch(let type, let context):
                                importErrorMessage = "Type '\(type)' mismatch: \(context.debugDescription)"
                            case .valueNotFound(let type, let context):
                                importErrorMessage = "Value of type '\(type)' not found: \(context.debugDescription)"
                            @unknown default:
                                importErrorMessage = "Unknown decoding error: \(decodingError.localizedDescription)"
                            }
                        } else {
                            importErrorMessage = "Failed to import: \(error.localizedDescription)"
                        }
                        showingImportError = true
                        isImporting = false
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete All Entries",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete All", role: .destructive) {
                    logStore.deleteAllEntries()
                    showingDeletedFeedback = true
                }
            },
            message: {
                Text("Are you sure you want to delete all log entries? This action cannot be undone.")
            }
        )
        .alert("Entries Deleted", isPresented: $showingDeletedFeedback) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All log entries have been successfully deleted.")
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Log entries were successfully imported.")
        }
    }
}

private struct AboutSection: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "Version \(version)"
    }
    
    var body: some View {
        Section {
            VStack(spacing: 8) {
                Text(appVersion)
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Text("Created with")
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("in Zurich")
                }
                .font(.footnote)
                .foregroundColor(.gray)
                
                Text("with the sea in our heart.")
                    .font(.footnote)
                    .foregroundColor(.gray)
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

struct LogEntriesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    
    var entries: [LogEntry]
    
    init(entries: [LogEntry]) {
        self.entries = entries
    }
    
    init(configuration: ReadConfiguration) throws {
        entries = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
}
