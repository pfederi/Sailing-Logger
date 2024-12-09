import SwiftUI

struct VoyageDetailRow: View {
    let title: String
    let value: String
    var icon: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        .frame(width: 24)
                }
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 2)
    }
} 