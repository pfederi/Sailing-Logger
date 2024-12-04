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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voyage Details")) {
                    TextField("Name", text: $name)
                    TextField("Boat Type", text: $boatType)
                    TextField("Boat Name", text: $boatName)
                }
                
                Section(header: Text("Crew")) {
                    ForEach(crew) { member in
                        HStack {
                            Text(member.name)
                            Spacer()
                            Text(member.role.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteCrew)
                    
                    Button(action: { showingAddCrew = true }) {
                        Label("Add Crew Member", systemImage: "person.badge.plus")
                    }
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
                        voyageStore.updateVoyage(voyage, name: name, crew: crew, boatType: boatType, boatName: boatName)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                AddCrewSheet(
                    crew: $crew,
                    isPresented: $showingAddCrew,
                    existingSkipper: hasSkipper
                )
            }
        }
    }
    
    private func deleteCrew(at offsets: IndexSet) {
        crew.remove(atOffsets: offsets)
    }
} 