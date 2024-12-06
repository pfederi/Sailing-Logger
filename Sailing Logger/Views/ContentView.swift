import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var voyageStore = VoyageStore()
    @StateObject private var logStore: LogStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var tileManager = OpenSeaMapTileManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showingSettings = false
    @State private var showingNewEntry = false
    @State private var showingNewVoyage = false
    @State private var showingArchive = false
    @State private var showingEditVoyage = false
    @State private var showingEndVoyageConfirmation = false
    @State private var showingVoyageDetail = false
    
    init() {
        let voyageStore = VoyageStore()
        _voyageStore = StateObject(wrappedValue: voyageStore)
        _logStore = StateObject(wrappedValue: LogStore(voyageStore: voyageStore))
    }
    
    private var shouldShowNewVoyage: Bool {
        voyageStore.voyages.isEmpty || !voyageStore.hasActiveVoyage
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - only show when no active voyage
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
                        MaritimeColors.oceanBlue
                            .ignoresSafeArea()
                    }
                }
                
                VStack(spacing: 0) {
                    // Voyage Header
                    if let activeVoyage = voyageStore.activeVoyage {
                        NavigationLink(destination: VoyageDetailView(
                            voyage: activeVoyage,
                            voyageStore: voyageStore,
                            locationManager: locationManager,
                            tileManager: tileManager,
                            logStore: logStore
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "point.topright.filled.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                                        .font(.system(size: 40))
                                        .foregroundColor(MaritimeColors.navy)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Voyage:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(activeVoyage.name)
                                            .font(.headline)
                                            .foregroundColor(MaritimeColors.navy)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground).opacity(0.9))
                        }
                        
                        Rectangle()
                            .fill(MaritimeColors.seafoam)
                            .frame(height: 1)
                    }
                    
                    // LogEntriesListView
                    if voyageStore.hasActiveVoyage {
                        if logStore.entries.isEmpty {
                            Spacer()
                            Text("Add your first log entry to start tracking your voyage.")
                                .padding()
                                .foregroundColor(MaritimeColors.navy)
                            Spacer()
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
                        Spacer()
                        Text("Start a new Voyage to begin logging entries.")
                            .padding()
                            .foregroundColor(MaritimeColors.navy)
                        Spacer()
                    }
                }
                
                // Action Button
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
                                Image(systemName: shouldShowNewVoyage ? "plus.rectangle.fill" : "plus")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text(shouldShowNewVoyage ? "New Voyage" : "Add Log Entry")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 24)
                            .frame(height: 56)
                            .background(MaritimeColors.navy)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MaritimeColors.seafoam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sailing Logger")
                        .font(.headline)
                        .foregroundColor(MaritimeColors.navy)
                }
            }
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
                voyageStore: voyageStore
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
                .tint(MaritimeColors.navy)
            }
        }
        .sheet(isPresented: $showingNewVoyage) {
            NavigationView {
                NewVoyageView(voyageStore: voyageStore, logStore: logStore)
                    .tint(MaritimeColors.navy)
            }
        }
        .sheet(isPresented: $showingEditVoyage) {
            if let activeVoyage = voyageStore.activeVoyage {
                NavigationView {
                    EditVoyageView(voyageStore: voyageStore, voyage: activeVoyage)
                        .tint(MaritimeColors.navy)
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
