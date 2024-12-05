import SwiftUI

struct VoyageDetailView: View {
    let voyage: Voyage
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @State private var showingEditSheet = false
    @State private var showingVoyageLog = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            // Voyage Details Section
            Section {
                VoyageDetailRow(title: "Name", value: voyage.name, icon: "tag.fill")
                VoyageDetailRow(title: "Boat", value: "\(voyage.boatName) (\(voyage.boatType))", icon: "sailboat.fill")
                VoyageDetailRow(title: "Start Date", value: voyage.startDate.formatted(date: .long, time: .shortened), icon: "calendar")
                if let endDate = voyage.endDate {
                    VoyageDetailRow(title: "End Date", value: endDate.formatted(date: .long, time: .shortened), icon: "calendar.badge.checkmark")
                }
            } header: {
                Label("Voyage Details", systemImage: "info.circle.fill")
            }
            
            // Stats Section
            Section {
                VoyageDetailRow(
                    title: "Total Distance",
                    value: String(format: "%.1f nm", voyage.logEntries.map { $0.distance }.max() ?? 0),
                    icon: "arrow.triangle.swap"
                )
                VoyageDetailRow(
                    title: "Motor Miles",
                    value: String(format: "%.1f nm", calculateMotorMiles()),
                    icon: "engine.combustion"
                )
                VoyageDetailRow(
                    title: "Max Speed",
                    value: String(format: "%.1f kts", voyage.logEntries.map { $0.speed }.max() ?? 0),
                    icon: "speedometer"
                )
                VoyageDetailRow(
                    title: "Max Wind",
                    value: String(format: "%.1f kts", voyage.logEntries.map { $0.wind.speedKnots }.max() ?? 0),
                    icon: "wind"
                )
                VoyageDetailRow(
                    title: "Log Entries",
                    value: "\(voyage.logEntries.count)",
                    icon: "list.bullet"
                )
            } header: {
                Label("Statistics", systemImage: "chart.bar.fill")
            }
            
            // Crew Section
            if !voyage.crew.isEmpty {
                Section {
                    ForEach(voyage.crew) { crewMember in
                        VoyageDetailRow(
                            title: crewMember.role.rawValue,
                            value: crewMember.name,
                            icon: "person.fill"
                        )
                    }
                } header: {
                    Label("Crew", systemImage: "person.3.fill")
                }
            }
        }
        .navigationTitle(voyage.name)
        .detailToolbar(
            showEdit: { showingEditSheet = true },
            showLog: { showingVoyageLog = true }
        )
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                EditVoyageView(
                    voyageStore: voyageStore,
                    voyage: voyage
                )
            }
        }
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
    
    private func calculateMotorMiles() -> Double {
        let sortedEntries = voyage.logEntries.sorted { $0.timestamp < $1.timestamp }
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
} 