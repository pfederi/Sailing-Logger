import SwiftUI

struct SlideToEndButton: View {
    let text: String
    let action: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    private let buttonHeight: CGFloat = 72
    private let capsuleSize: CGFloat = 64
    private let padding: CGFloat = 4
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: buttonHeight/2)
                .fill(Color(uiColor: .systemBackground))
                .overlay(
                    Text(text)
                        .foregroundColor(.secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: buttonHeight/2)
                        .strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2)
                )
            
            // Expanding Red Background
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(MaritimeColors.coral(for: colorScheme))
                    .frame(width: offset + capsuleSize)
                    .padding(4)
                
                Image(systemName: "flag.checkered.2.crossed")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
                    .frame(width: capsuleSize)
                    .padding(4)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newOffset = max(0, min(value.translation.width, width - capsuleSize - 8))
                        offset = newOffset
                    }
                    .onEnded { value in
                        if offset > width * 0.7 {
                            withAnimation {
                                action()
                                offset = 0
                            }
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .frame(height: buttonHeight)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        width = geo.size.width
                    }
            }
        )
    }
} 