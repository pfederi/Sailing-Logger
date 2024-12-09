import SwiftUI

struct EditingCrew: Identifiable {
    let id: Int
    let index: Int
}

struct EditVoyageView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var voyageStore: VoyageStore
    let voyage: Voyage
    
    enum SheetMode {
        case add
        case edit(Int)
    }
    
    @State private var name: String
    @State private var crew: [CrewMember]
    @State private var boatType: String
    @State private var boatName: String
    @State private var editingCrew: EditingCrew? = nil
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
        voyageStore.updateVoyage(
            voyage,
            name: name,
            crew: crew,
            boatType: boatType,
            boatName: boatName
        )
        
        // Schließe nur die Sheets, nicht die gesamte View
        editingCrew = nil
        showingAddCrew = false
    }
    
    var body: some View {
        NavigationView {
            Form {
                voyageDetailsSection
                crewSection
            }
            .navigationTitle("Edit Voyage")
            .navigationBarTitleDisplayMode(.inline)
            .tint(MaritimeColors.navy(for: colorScheme))
            .toolbar { toolbarItems }
            .sheet(item: $editingCrew) { crew in
                NavigationView {
                    EditCrewMemberView(
                        crew: $crew,
                        index: crew.index,
                        hasSkipper: hasSkipper
                    )
                    .navigationTitle("Edit Crew Member")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                editingCrew = nil
                            }
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                editingCrew = nil
                            }
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                AddCrewSheet(
                    crew: $crew,
                    isPresented: $showingAddCrew,
                    crewToEditIndex: $crewToEditIndex,
                    existingSkipper: hasSkipper,
                    onSave: saveChanges
                )
            }
        }
    }
    
    private var voyageDetailsSection: some View {
        Group {
            Section(header: Text("Voyage Details")) {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    TextField("Voyage Name", text: $name)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text(voyage.startDate.formatted(date: .long, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Boat Details")) {
                HStack {
                    Image(systemName: "sailboat")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    TextField("Boat Type", text: $boatType)
                }
                
                HStack {
                    Image(systemName: "pencil.and.scribble")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    TextField("Boat Name", text: $boatName)
                }
            }
        }
    }
    
    private var crewSection: some View {
        Section(header: Text("Crew")) {
            // Skipper und Second Skipper
            ForEach(crew.filter { $0.role == .skipper || $0.role == .secondSkipper }) { member in
                CrewMemberRow(
                    member: member,
                    onEdit: {
                        if let index = crew.firstIndex(where: { $0.id == member.id }) {
                            editingCrew = EditingCrew(id: index, index: index)
                        }
                    },
                    onDelete: {
                        if let index = crew.firstIndex(where: { $0.id == member.id }) {
                            crew.remove(at: index)
                            // Speichere Änderungen sofort
                            saveChanges()
                        }
                    }
                )
            }
            
            // Normale Crew-Mitglieder
            let crewMembers = crew.filter { $0.role == .crew }
            ForEach(crewMembers) { member in
                CrewMemberRow(
                    member: member,
                    onEdit: {
                        if let index = crew.firstIndex(where: { $0.id == member.id }) {
                            editingCrew = EditingCrew(id: index, index: index)
                        }
                    },
                    onDelete: {
                        if let index = crew.firstIndex(where: { $0.id == member.id }) {
                            crew.remove(at: index)
                            // Speichere Änderungen sofort
                            saveChanges()
                        }
                    }
                )
            }
            .onMove { from, to in
                var updatedCrewMembers = crewMembers
                updatedCrewMembers.move(fromOffsets: from, toOffset: to)
                let skippers = crew.filter { $0.role == .skipper || $0.role == .secondSkipper }
                crew = skippers + updatedCrewMembers
                // Speichere Änderungen nach dem Verschieben
                saveChanges()
            }
            
            Button(action: { 
                showingAddCrew = true 
            }) {
                Label("Add Crew Member", systemImage: "person.badge.plus")
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
        }
    }
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
        }
    }
}

struct EditCrewMemberView: View {
    @Binding var crew: [CrewMember]
    @Environment(\.colorScheme) var colorScheme
    let index: Int
    let hasSkipper: Bool
    
    var body: some View {
        Form {
            TextField("Name", text: .init(
                get: { crew[index].name },
                set: { updateName($0) }
            ))
            
            Picker("Role", selection: .init(
                get: { crew[index].role },
                set: { updateRole($0) }
            )) {
                Text(CrewRole.skipper.rawValue).tag(CrewRole.skipper)
                    .disabled(hasSkipper && crew[index].role != .skipper)
                Text(CrewRole.secondSkipper.rawValue).tag(CrewRole.secondSkipper)
                    .disabled(crew.contains { $0.role == .secondSkipper } && crew[index].role != .secondSkipper)
                Text(CrewRole.crew.rawValue).tag(CrewRole.crew)
            }
            .tint(MaritimeColors.navy(for: colorScheme))
        }
        .tint(MaritimeColors.navy(for: colorScheme))
    }
    
    private func updateName(_ name: String) {
        var member = crew[index]
        member.name = name
        crew[index] = member
    }
    
    private func updateRole(_ role: CrewRole) {
        var member = crew[index]
        member.role = role
        crew[index] = member
    }
}
 