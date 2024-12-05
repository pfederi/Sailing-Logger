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
                // Background
                Color.clear.overlay(
                    Image("background-image")
                        .resizable()
                        .scaledToFill()
                )
                .ignoresSafeArea()
                .opacity(0.33)
                
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
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Voyage:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(activeVoyage.name)
                                            .font(.headline)
                                    }
                                    
                                    Spacer()
                                    Menu {
                                        Button(role: .destructive) {
                                            showingEndVoyageConfirmation = true
                                        } label: {
                                            Label("End Voyage", systemImage: "xmark.circle")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground).opacity(0.9))
                        }
                    }
                    
                    // LogEntriesListView
                    if voyageStore.hasActiveVoyage {
                        LogEntriesListView(
                            logStore: logStore,
                            voyageStore: voyageStore,
                            locationManager: locationManager,
                            tileManager: tileManager
                        )
                    } else {
                        Spacer()
                        Text("Start a new Voyage to begin logging entries.")
                            .padding()
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
                                Text(shouldShowNewVoyage ? "New Voyage" : "Add Log Entry")
                                    .font(.title3)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .frame(height: 56)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Sailing Logger")
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
            }
        }
        .sheet(isPresented: $showingNewVoyage) {
            NewVoyageView(voyageStore: voyageStore)
        }
        .sheet(isPresented: $showingEditVoyage) {
            if let activeVoyage = voyageStore.activeVoyage {
                EditVoyageView(voyageStore: voyageStore, voyage: activeVoyage)
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
