import SwiftUI

struct CrewMemberRow: View {
    let member: CrewMember
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                if member.role == .crew {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                } else if member.role == .skipper {
                    Image(systemName: "sailboat.circle.fill")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        .font(.system(size: 24))
                } else if member.role == .secondSkipper {
                    Image(systemName: "sailboat.circle")
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading) {
                    Text(member.name)
                    Text(member.role.rawValue)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme).opacity(0.6))
                        .font(.caption)
                }
                Spacer()
            }
        }
        .tint(MaritimeColors.navy(for: colorScheme))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CrewSection: View {
    @Binding var crew: [CrewMember]
    @Binding var showingAddCrew: Bool
    @Binding var crewToEditIndex: Int?
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) var colorScheme
    let hasSkipper: Bool
    
    var body: some View {
        let skippers = crew.filter { $0.role == .skipper || $0.role == .secondSkipper }
            .sorted { member1, member2 in
                if member1.role == .skipper { return true }
                if member2.role == .skipper { return false }
                return false
            }
        
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
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
            }
        }
        .tint(MaritimeColors.navy(for: colorScheme))
    }
}