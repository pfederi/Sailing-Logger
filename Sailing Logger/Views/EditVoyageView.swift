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
                            VStack(alignment: .leading) {
                                Text(member.name)
                                Text(member.role.rawValue)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = crew.firstIndex(where: { $0.id == member.id }) {
                                    crew.remove(at: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                            
                            Button {
                                if let index = crew.firstIndex(where: { $0.id == member.id }) {
                                    crewToEditIndex = index
                                    showingAddCrew = true
                                }
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(MaritimeColors.navy)
                        }
                    }
                    
                    Button(action: { 
                        crewToEditIndex = nil
                        showingAddCrew = true 
                    }) {
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
                    crewToEditIndex: $crewToEditIndex,
                    existingSkipper: hasSkipper
                )
            }
        }
    }
} 