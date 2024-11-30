import SwiftUI

struct RegionNameInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var regionName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Region Name", text: $regionName)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Enter a name for this map region")
                }
            }
            .navigationTitle("Name Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        regionName = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        onSave(regionName)
                        regionName = ""
                        dismiss()
                    }
                    .disabled(regionName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
} 