import SwiftUI

struct MainToolbarModifier: ViewModifier {
    let showSettings: () -> Void
    let hasArchivedVoyages: Bool
    let voyageStore: VoyageStore
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    let logStore: LogStore
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(MaritimeColors.navy)
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
                            Text("Archive")
                                .foregroundColor(MaritimeColors.navy)
                        }
                    }
                }
            }
            .toolbarBackground(MaritimeColors.seafoam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
    
    private enum Field: Hashable {
        case field1  // Erweitere dies nach Bedarf
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                // Navigation Bar Items
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showEdit()
                        } label: {
                            Text("Edit")
                                .foregroundColor(MaritimeColors.navy)
                        }
                        
                        Button {
                            showLog()
                        } label: {
                            Image(systemName: "doc.text")
                                .foregroundColor(MaritimeColors.navy)
                        }
                    }
                }
                
                // Keyboard Toolbar Items
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
            .toolbarBackground(MaritimeColors.seafoam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(MaritimeColors.seafoam, for: .navigationBar)
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