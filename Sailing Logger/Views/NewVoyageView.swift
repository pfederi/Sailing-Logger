import SwiftUI

struct NewVoyageView: View {
    @Environment(\.dismiss) var dismiss
    @State private var voyageName = ""
    @State private var startDate = Date()
    @State private var startLocation = ""
    @State private var plannedDestination = ""
    @State private var boat = ""
    
    var body: some View {
        Form {
            Section(header: Text("Voyage Details")) {
                TextField("Voyage Name", text: $voyageName)
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                TextField("Start Location", text: $startLocation)
                TextField("Planned Destination", text: $plannedDestination)
                TextField("Boat", text: $boat)
            }
            
            Section {
                Button("Create Voyage") {
                    // TODO: Save voyage
                    dismiss()
                }
                .disabled(voyageName.isEmpty || startLocation.isEmpty)
                
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
        }
        .navigationTitle("New Voyage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        NewVoyageView()
    }
} 