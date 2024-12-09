import SwiftUI

struct MainToolbarModifier: ViewModifier {
    let showSettings: () -> Void
    let hasArchivedVoyages: Bool
    let voyageStore: VoyageStore
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    let logStore: LogStore
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(colorScheme == .dark ? MaritimeColors.navyDark : MaritimeColors.navy)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasArchivedVoyages {
                        NavigationLink {
                            VoyageArchiveView(
                                voyageStore: voyageStore,
                                locationManager: locationManager,
                                tileManager: tileManager,
                                logStore: logStore
                            )
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                                .foregroundColor(colorScheme == .dark ? MaritimeColors.navyDark : MaritimeColors.navy)
                        }
                    }
                }
            }
            .toolbarBackground(MaritimeColors.seafoam(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
    }
}

extension View {
    func mainToolbar(
        showSettings: @escaping () -> Void,
        hasArchivedVoyages: Bool,
        voyageStore: VoyageStore,
        locationManager: LocationManager,
        tileManager: OpenSeaMapTileManager,
        logStore: LogStore
    ) -> some View {
        modifier(MainToolbarModifier(
            showSettings: showSettings,
            hasArchivedVoyages: hasArchivedVoyages,
            voyageStore: voyageStore,
            locationManager: locationManager,
            tileManager: tileManager,
            logStore: logStore
        ))
    }
}

struct DetailToolbarModifier: ViewModifier {
    let showEdit: () -> Void
    let showLog: () -> Void
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) var colorScheme
    
    private enum Field: Hashable {
        case field1
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showEdit()
                        } label: {
                            Text("Edit")
                                .foregroundColor(colorScheme == .dark ? MaritimeColors.navyDark : MaritimeColors.navy)
                        }
                        
                        Button {
                            showLog()
                        } label: {
                            Image(systemName: "doc.text")
                                .foregroundColor(colorScheme == .dark ? MaritimeColors.navyDark : MaritimeColors.navy)
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: {
                        // Previous field logic
                    }) {
                        Image(systemName: "chevron.up")
                    }
                    
                    Button(action: {
                        // Next field logic
                    }) {
                        Image(systemName: "chevron.down")
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .toolbarBackground(MaritimeColors.seafoam(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
    }
}

extension View {
    func detailToolbar(
        showEdit: @escaping () -> Void,
        showLog: @escaping () -> Void
    ) -> some View {
        modifier(DetailToolbarModifier(
            showEdit: showEdit,
            showLog: showLog
        ))
    }
}

struct LogViewToolbarModifier: ViewModifier {
    let dismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? .white : MaritimeColors.navy)
                }
            }
            .toolbarBackground(MaritimeColors.seafoam(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func logViewToolbar(
        dismiss: @escaping () -> Void
    ) -> some View {
        modifier(LogViewToolbarModifier(dismiss: dismiss))
    }
} 