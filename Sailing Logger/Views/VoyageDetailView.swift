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
    @State private var showingEndVoyageAlert = false
    
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
                    value: voyage.name, 
                    icon: "tag.fill"
                )
                if !voyage.boatName.isEmpty || !voyage.boatType.isEmpty {
                    VoyageDetailRow(
                        title: "Boat", 
                        value: voyage.boatType.isEmpty || voyage.boatName.isEmpty ? 
                               voyage.boatName + voyage.boatType :
                               "\(voyage.boatName) (\(voyage.boatType))", 
                        icon: "sailboat.fill"
                    )
                }
                VoyageDetailRow(title: "Start Date", value: voyage.startDate.formatted(date: .long, time: .shortened), icon: "calendar")
                if let endDate = voyage.endDate {
                    VoyageDetailRow(title: "End Date", value: endDate.formatted(date: .long, time: .shortened), icon: "calendar.badge.checkmark")
                }
            } header: {
                Label("Voyage Details", systemImage: "info.circle.fill")
                    .fontWeight(.bold)
                    .foregroundColor(MaritimeColors.navy)
            }
            // Crew Section
            if !voyage.crew.isEmpty {
                Section {
                    let sortedCrew = voyage.crew.sorted { member1, member2 in
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
            if !voyage.logEntries.isEmpty {
                Section {
                    if let maxDistance = voyage.logEntries.map({ $0.distance }).max() {
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
                    
                    if let maxSpeed = voyage.logEntries.map({ $0.speed }).max() {
                        VoyageDetailRow(
                            title: "Max Speed",
                            value: String(format: "%.1f kts", maxSpeed),
                            icon: "speedometer"
                        )
                    }
                    
                    if let maxWind = voyage.logEntries.map({ $0.wind.speedKnots }).max() {
                        VoyageDetailRow(
                            title: "Max Wind",
                            value: String(format: "%.1f kts", maxWind),
                            icon: "wind"
                        )
                    }
                    
                    VoyageDetailRow(
                        title: "Log Entries",
                        value: "\(voyage.logEntries.count)",
                        icon: "list.bullet"
                    )
                } header: {
                    Label("Statistics", systemImage: "chart.bar.fill")
                        .fontWeight(.bold)
                        .foregroundColor(MaritimeColors.navy)
                }
            }

            // Log Entries Section - nur für archivierte Voyages
            if voyage.endDate != nil {
                Section {
                    ForEach(voyage.logEntries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
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

            // End Voyage Button Section
            if voyage.endDate == nil {
                Section {
                    SlideToEndButton(
                        text: "Slide to End Voyage",
                        action: {
                            showingEndVoyageAlert = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
        .alert("End Voyage?", isPresented: $showingEndVoyageAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Voyage", role: .destructive) {
                endVoyage()
            }
        } message: {
            Text("Once a voyage is ended, no further modifications to the logs will be possible. This action cannot be undone.")
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
    
    private func endVoyage() {
        let updatedVoyage = voyage
        updatedVoyage.endDate = Date()
        if let index = voyageStore.voyages.firstIndex(where: { $0.id == voyage.id }) {
            voyageStore.voyages[index] = updatedVoyage
            dismiss()
            voyageStore.resetActiveVoyageIfCompleted()
        }
    }
} 