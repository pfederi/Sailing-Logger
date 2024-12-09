import SwiftUI

struct ManeuverSelectionView: View {
    @Binding var selectedManeuver: Maneuver?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List(Maneuver.allCases, id: \.self) { maneuver in
            Button {
                selectedManeuver = maneuver
            } label: {
                HStack {
                    Text(maneuver.rawValue)
                    Spacer()
                    if selectedManeuver == maneuver {
                        Image(systemName: "checkmark")
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .tint(MaritimeColors.navy(for: colorScheme))
    }
} 
