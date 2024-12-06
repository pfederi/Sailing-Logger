import SwiftUI

struct CrewMemberRow: View {
    let member: CrewMember
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                if member.role == .crew {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.gray)
                } else if member.role == .skipper {
                    Image(systemName: "sailboat.circle.fill")
                        .foregroundColor(MaritimeColors.navy)
                        .font(.system(size: 24))
                } else if member.role == .secondSkipper {
                    Image(systemName: "sailboat.circle")
                        .foregroundColor(MaritimeColors.navy)
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading) {
                    Text(member.name)
                    Text(member.role.rawValue)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                Spacer()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

struct CrewSection: View {
    @Binding var crew: [CrewMember]
    @Binding var showingAddCrew: Bool
    @Binding var crewToEditIndex: Int?
    @Environment(\.editMode) private var editMode
    let hasSkipper: Bool
    
    var body: some View {
        let skippers = crew.filter { $0.role == .skipper || $0.role == .secondSkipper }
            .sorted { member1, member2 in
                if member1.role == .skipper { return true }
                if member2.role == .skipper { return false }
                return false
            }
        
        // Skipper Section nur anzeigen, wenn Skipper vorhanden sind
        if !skippers.isEmpty {
            Section(header: Text("Skippers")) {
                ForEach(skippers) { member in
                    CrewMemberRow(
                        member: member,
                        onEdit: {
                            crewToEditIndex = crew.firstIndex(where: { $0.id == member.id })
                            showingAddCrew = true
                        },
                        onDelete: {
                            if let index = crew.firstIndex(where: { $0.id == member.id }) {
                                crew.remove(at: index)
                            }
                        }
                    )
                }
            }
        }
        
        // Crew Section
        Section(header: Text("Crew Members")) {
            let crewMembers = crew.filter { $0.role == .crew }
            
            ForEach(crewMembers) { member in
                CrewMemberRow(
                    member: member,
                    onEdit: {
                        if let index = crew.firstIndex(where: { $0.id == member.id }) {
                            crewToEditIndex = index
                            showingAddCrew = true
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
                crew = skippers + updatedCrewMembers
            }
            .environment(\.editMode, .constant(.active))
            
            Button(action: { 
                crewToEditIndex = nil
                showingAddCrew = true 
            }) {
                Label("Add Crew Member", systemImage: "person.badge.plus")
            }
        }
    }
}