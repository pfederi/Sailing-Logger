import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            if isActive {
                ContentView()
            } else {
                Color.clear.overlay(
                    Image("background-image")
                        .resizable()
                        .scaledToFill()
                )
                .ignoresSafeArea()
                .opacity(0.33)
                
                VStack(spacing: 20) {
                    Image(systemName: "helm")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Sailing Logger")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your digital logbook")
                        .font(.title3)
                        .foregroundColor(.black)
                }
                .scaleEffect(isActive ? 1.1 : 1.0)
                .opacity(isActive ? 0 : 1)
                .animation(.easeIn(duration: 0.5), value: isActive)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
} 
