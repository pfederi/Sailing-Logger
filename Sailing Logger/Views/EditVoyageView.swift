import SwiftUI

struct EditVoyageView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var voyageStore: VoyageStore
    let voyage: Voyage
    
    @State private var name: String
    @State private var crew: [CrewMember]
    @State private var boatType: String
    @State private var boatName: String
    @State private var showingAddCrew = false
    @State private var crewToEditIndex: Int?
    
    init(voyageStore: VoyageStore, voyage: Voyage) {
        self.voyageStore = voyageStore
        self.voyage = voyage
        _name = State(initialValue: voyage.name)
        _crew = State(initialValue: voyage.crew)
        _boatType = State(initialValue: voyage.boatType)
        _boatName = State(initialValue: voyage.boatName)
    }
    
    private var hasSkipper: Bool {
        crew.contains { $0.role == .skipper }
    }
    
    private func saveChanges() {
        let updatedVoyage = voyage
        updatedVoyage.name = name
        updatedVoyage.boatType = boatType
        updatedVoyage.boatName = boatName
        updatedVoyage.crew = crew
        
        if let index = voyageStore.voyages.firstIndex(where: { $0.id == voyage.id }) {
            voyageStore.voyages[index] = updatedVoyage
        }
        
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voyage Details")) {
                    TextField("Name", text: $name)
                    TextField("Boat Type", text: $boatType)
                    TextField("Boat Name", text: $boatName)
                }
                
                Section(header: Text("Crew")) {
                    CrewSection(
                        crew: $crew,
                        showingAddCrew: $showingAddCrew,
                        crewToEditIndex: $crewToEditIndex,
                        hasSkipper: hasSkipper
                    )
                }
            }
            .navigationTitle("Edit Voyage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                AddCrewSheet(
                    crew: $crew,
                    isPresented: $showingAddCrew,
                    crewToEditIndex: $crewToEditIndex,
                    existingSkipper: hasSkipper
                )
            }
        }
    }
} 