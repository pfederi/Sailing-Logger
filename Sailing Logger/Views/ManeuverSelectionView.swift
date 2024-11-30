import SwiftUI

struct ManeuverSelectionView: View {
    @Binding var selectedManeuver: Maneuver?
    
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
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
} 
