import SwiftUI

struct EditingCrew: Identifiable {
    let id: Int
    let index: Int
}

struct EditVoyageView: View {
    @Environment(\.dismiss) var dismiss
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
                voyageDetailsSection
                crewSection
            }
            .navigationTitle("Edit Voyage")
            .navigationBarTitleDisplayMode(.inline)
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
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                editingCrew = nil
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                NavigationView {
                    AddCrewMemberView(
                        crew: $crew,
                        hasSkipper: hasSkipper
                    )
                }
            }
        }
    }
    
    private var voyageDetailsSection: some View {
        Group {
            Section(header: Text("Voyage Details")) {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(MaritimeColors.navy)
                    TextField("Voyage Name", text: $name)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(MaritimeColors.navy)
                    Text(voyage.startDate.formatted(date: .long, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Boat Details")) {
                HStack {
                    Image(systemName: "sailboat")
                        .foregroundColor(MaritimeColors.navy)
                    TextField("Boat Type", text: $boatType)
                }
                
                HStack {
                    Image(systemName: "pencil.and.scribble")
                        .foregroundColor(MaritimeColors.navy)
                    TextField("Boat Name", text: $boatName)
                }
            }
        }
    }
    
    private var crewSection: some View {
        Section(header: Text("Crew")) {
            // Zuerst die Skipper anzeigen
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
                        }
                    }
                )
            }
            
            // Dann die normalen Crew-Mitglieder mit Drag & Drop
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
                        }
                    }
                )
            }
            .onMove { from, to in
                var updatedCrewMembers = crewMembers
                updatedCrewMembers.move(fromOffsets: from, toOffset: to)
                // Kombiniere Skipper und verschobene Crew-Mitglieder
                let skippers = crew.filter { $0.role == .skipper || $0.role == .secondSkipper }
                crew = skippers + updatedCrewMembers
            }
            .environment(\.editMode, .constant(.active))
            
            Button(action: { 
                showingAddCrew = true 
            }) {
                Label("Add Crew Member", systemImage: "person.badge.plus")
            }
        }
    }
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct EditCrewMemberView: View {
    @Binding var crew: [CrewMember]
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
        }
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

struct AddCrewMemberView: View {
    @Binding var crew: [CrewMember]
    @Environment(\.dismiss) var dismiss
    let hasSkipper: Bool
    
    @State private var name = ""
    @State private var role: CrewRole
    
    init(crew: Binding<[CrewMember]>, hasSkipper: Bool) {
        self._crew = crew
        self.hasSkipper = hasSkipper
        self._role = State(initialValue: hasSkipper ? .crew : .skipper)
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            
            Picker("Role", selection: $role) {
                Text(CrewRole.skipper.rawValue).tag(CrewRole.skipper)
                    .disabled(hasSkipper)
                Text(CrewRole.secondSkipper.rawValue).tag(CrewRole.secondSkipper)
                    .disabled(crew.contains { $0.role == .secondSkipper })
                Text(CrewRole.crew.rawValue).tag(CrewRole.crew)
            }
        }
        .navigationTitle("Add Crew Member")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    let newMember = CrewMember(name: name, role: role)
                    crew.append(newMember)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
} 