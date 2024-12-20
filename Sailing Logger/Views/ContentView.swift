import SwiftUI
import MapKit
import CoreLocation

private struct VoyageHeaderContent: View {
    let voyage: Voyage
    @ObservedObject var logStore: LogStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "point.topright.filled.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                    .font(.system(size: 32))
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    .alignmentGuide(.firstTextBaseline) { d in
                        d[.top]
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(voyage.name)
                        .font(.headline)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("\(voyage.boatName) (\(voyage.boatType))")
                        .font(.subheadline)
                    Text("Total Distance: \(String(format: "%.1f", logStore.totalDistance)) nm")
                        .font(.subheadline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.trailing, 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.9))
    }
}

struct ContentView: View {
    private static func createDependencies() -> (LocationManager, VoyageStore, LogStore) {
        let locationManager = LocationManager()
        let voyageStore = VoyageStore(locationManager: locationManager)
        let logStore = LogStore(voyageStore: voyageStore)
        return (locationManager, voyageStore, logStore)
    }
    
    private static let dependencies = createDependencies()
    
    @StateObject private var locationManager: LocationManager
    @StateObject private var voyageStore: VoyageStore
    @StateObject private var logStore: LogStore
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var tileManager = OpenSeaMapTileManager()
    
    @State private var showingNewVoyage = false
    @State private var showingSettings = false
    @State private var showingEditVoyage = false
    @State private var showingEndVoyageConfirmation = false
    @State private var showingVoyageDetail = false
    @State private var showingNewEntry = false
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        _locationManager = StateObject(wrappedValue: Self.dependencies.0)
        _voyageStore = StateObject(wrappedValue: Self.dependencies.1)
        _logStore = StateObject(wrappedValue: Self.dependencies.2)
    }
    
    private var shouldShowNewVoyage: Bool {
        voyageStore.voyages.isEmpty || !voyageStore.hasActiveVoyage
    }
    
    private var backgroundView: some View {
        Group {
            if shouldShowNewVoyage {
                if let _ = UIImage(named: "background-image") {
                    Color.clear.overlay(
                        Image("background-image")
                            .resizable()
                            .scaledToFill()
                    )
                    .ignoresSafeArea()
                    .opacity(0.33)
                } else {
                    MaritimeColors.oceanBlue(for: colorScheme)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private var voyageHeaderView: some View {
        Group {
            if let activeVoyage = voyageStore.activeVoyage {
                VStack(spacing: 0) {
                    NavigationLink(destination: VoyageDetailView(
                        voyage: activeVoyage,
                        voyageStore: voyageStore,
                        locationManager: locationManager,
                        tileManager: tileManager,
                        logStore: logStore
                    )) {
                        VoyageHeaderContent(voyage: activeVoyage, logStore: logStore)
                    }
                    
                    // Tracking Status Bar - nur anzeigen wenn Auto-Tracking aktiviert ist
                    if UserDefaults.standard.bool(forKey: "AutoTrackingEnabled") {
                        HStack(spacing: 12) {
                            if let activeVoyage = voyageStore.activeVoyage {
                                if locationManager.isTrackingActive {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Location tracking active")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Current speed: \(String(format: "%.1f", locationManager.currentSpeed)) kts")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            voyageStore.updateVoyageTracking(activeVoyage, isTracking: false)
                                            locationManager.stopBackgroundTracking()
                                        }
                                    } label: {
                                        Text("Stop")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                } else {
                                    Image(systemName: "location.slash.fill")
                                        .foregroundColor(.secondary)
                                    Text("Location tracking stopped")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            voyageStore.updateVoyageTracking(activeVoyage, isTracking: true)
                                            locationManager.startBackgroundTracking(interval: 10)
                                        }
                                    } label: {
                                        Text("Start")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(locationManager.isTrackingActive ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                    }
                }
            }
        }
    }
    
    private var mainContentView: some View {
        Group {
            if voyageStore.hasActiveVoyage {
                if logStore.entries.isEmpty {
                    VStack {
                        Spacer()
                        Text("Add your first log entry to start tracking your voyage.")
                            .padding()
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        Spacer()
                    }
                } else {
                    LogEntriesListView(
                        logStore: logStore,
                        voyageStore: voyageStore,
                        locationManager: locationManager,
                        tileManager: tileManager
                    )
                    .background(Color(UIColor.systemGray6).opacity(0.5))
                }
            } else {
                VStack {
                    Spacer()
                    Text("Start a new Voyage to begin logging entries.")
                        .padding()
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Spacer()
                }
            }
        }
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    if shouldShowNewVoyage {
                        showingNewVoyage = true
                    } else {
                        showingNewEntry = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: shouldShowNewVoyage ? "plus.rectangle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(colorScheme == .dark ? MaritimeColors.navy : .white)
                        Text(shouldShowNewVoyage ? "New Voyage" : "Add Log Entry")
                            .font(.title3)
                            .foregroundColor(colorScheme == .dark ? MaritimeColors.navy : .white)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    .background(MaritimeColors.navy(for: colorScheme))
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                
                VStack(spacing: 0) {
                    voyageHeaderView
                    
                    if voyageStore.activeVoyage != nil {
                        Rectangle()
                            .fill(MaritimeColors.seafoam)
                            .frame(height: 1)
                    }
                    
                    mainContentView
                }
                
                floatingActionButton
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar(
                showSettings: { showingSettings = true },
                hasArchivedVoyages: voyageStore.voyages.contains(where: { $0.endDate != nil }),
                voyageStore: voyageStore,
                locationManager: locationManager,
                tileManager: tileManager,
                logStore: logStore
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                themeManager: themeManager,
                logStore: logStore,
                tileManager: tileManager,
                voyageStore: voyageStore,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showingNewEntry) {
            NavigationView {
                NewLogEntryView(
                    logStore: logStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    themeManager: themeManager
                )
                .tint(MaritimeColors.navy(for: colorScheme))
            }
        }
        .sheet(isPresented: $showingNewVoyage) {
            NewVoyageView(
                voyageStore: voyageStore,
                logStore: logStore,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showingEditVoyage) {
            if let activeVoyage = voyageStore.activeVoyage {
                NavigationView {
                    EditVoyageView(voyageStore: voyageStore, voyage: activeVoyage)
                        .tint(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
        .confirmationDialog(
            "End Voyage",
            isPresented: $showingEndVoyageConfirmation,
            actions: {
                Button("End Voyage", role: .destructive) {
                    if let activeVoyage = voyageStore.activeVoyage {
                        voyageStore.endVoyage(activeVoyage)
                    }
                }
            },
            message: {
                Text("Are you sure you want to end the current voyage? This action cannot be undone.")
            }
        )
        .sheet(isPresented: $showingVoyageDetail) {
            NavigationView {
                VoyageDetailView(
                    voyage: voyageStore.activeVoyage!,
                    voyageStore: voyageStore,
                    locationManager: locationManager,
                    tileManager: tileManager,
                    logStore: logStore
                )
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .alert("Offline", isPresented: $tileManager.showOfflineAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need to be online to download map tiles. Please check your internet connection and try again.")
        }
        .task {
            await logStore.updateLocationDescriptions()
        }
        .onAppear {
            voyageStore.resetActiveVoyageIfCompleted()
        }
    }
}

#Preview {
    ContentView()
} 
