import SwiftUI

struct SplashScreenView: View {
    @Binding var showSplash: Bool
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Just\nWatched.")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 40)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 3.0)) {
                opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showSplash = false
            }
        }
    }
} 