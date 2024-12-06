import SwiftUI

struct SlideToEndButton: View {
    let text: String
    let action: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .overlay(
                    HStack {
                        Spacer()
                        Text(text)
                            .foregroundColor(.gray)
                            .padding(.trailing, 50)
                        Spacer()
                    }
                )
            
            // Slider
            HStack {
                Capsule()
                    .fill(Color.red)
                    .frame(width: 50, height: 50)
                    .padding(4)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = max(0, min(value.translation.width, width - 58))
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
                    .overlay(
                        Image(systemName: "flag.checkered.2.crossed")
                            .foregroundColor(.white)
                            .offset(x: offset)
                    )
                Spacer()
            }
        }
        .frame(height: 58)
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