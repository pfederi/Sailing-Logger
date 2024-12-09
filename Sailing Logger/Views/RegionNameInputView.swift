import SwiftUI

struct RegionNameInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
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
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Name Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        regionName = ""
                        dismiss()
                    }
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        onSave(regionName)
                        regionName = ""
                        dismiss()
                    }
                    .disabled(regionName.isEmpty)
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
} 