import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var logStore = LogStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var tileManager = OpenSeaMapTileManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showingSettings = false
    @State private var showingNewEntry = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                    Color.clear.overlay(
                        Image("background-image")
                                .resizable()
                                .scaledToFill()
                                )
                        .ignoresSafeArea()
                        .opacity(0.33)
                LogEntriesListView(
                    logStore: logStore,
                    locationManager: locationManager,
                    tileManager: tileManager
                )
                    .navigationTitle("Sailing Logger")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .padding(.trailing, 4)
                            }
                        }
                    }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingNewEntry = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 32  )
                        .padding(.bottom, 0)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    themeManager: themeManager,
                    logStore: logStore,
                    tileManager: tileManager
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
    }
}

#Preview {
    ContentView()
} 
