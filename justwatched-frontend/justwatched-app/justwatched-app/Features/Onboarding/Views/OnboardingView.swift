import SwiftUI

struct AnimatedGradientIcon: View {
    let systemName: String
    let palette: [Color]
    @State private var angle: Double = 0.0

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .padding()
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(colors: palette),
                    center: .topLeading,
                    startAngle: .degrees(angle),
                    endAngle: .degrees(angle + 360)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("isNewUser") var isNewUser: Bool = false
    @State private var selection = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                OnboardingScreen(
                    title: "Welcome to JustWatched. 🎬",
                    text: "This isn't just another movie app.\n\nDiscover films your way.",
                    imageName: "film",
                    palette: [.red, .orange, .pink, .red],
                    cta: "Next",
                    onNext: { selection += 1 }
                ).tag(0)
                OnboardingScreen(
                    title: "Smart recs. Just for you.",
                    text: "The more you review, the better your suggestions get.\n\nOur AI learns your taste — no generic top-10s.",
                    imageName: "sparkles",
                    palette: [.blue, .cyan, .purple, .blue],
                    cta: "Next",
                    onNext: { selection += 1 }
                ).tag(1)
                OnboardingScreen(
                    title: "Friends-only sharing 👀",
                    text: "No followers. No strangers.\n\nSee what your people are watching and loving.",
                    imageName: "person.2",
                    palette: [.yellow, .orange, .white, .yellow],
                    cta: "Next",
                    onNext: { selection += 1 }
                ).tag(2)
                OnboardingScreen(
                    title: "Movie night, solved.",
                    text: "Create a room, invite friends,\n\nand let AI pick something everyone will love.",
                    imageName: "popcorn",
                    palette: [.green, .mint, .teal, .green],
                    cta: "Next",
                    onNext: { selection += 1 }
                ).tag(3)
                OnboardingScreen(
                    title: "Let's make your watchlist ✨",
                    text: "Add your first movie, write a quick review,\n\nor invite a friend. Just start where you feel like.",
                    imageName: "star",
                    palette: [.pink, .purple, .white, .pink],
                    cta: "Go to App",
                    onNext: { 
                        hasSeenOnboarding = true
                        isNewUser = false // Reset new user flag
                    }
                ).tag(4)
            }
            .tabViewStyle(PageTabViewStyle())
            .padding(.vertical, 32)
            .overlay(
                HStack {
                    Spacer()
                    Button("Skip") { 
                        hasSeenOnboarding = true
                        isNewUser = false // Reset new user flag
                    }
                        .foregroundColor(.white)
                        .padding()
                }, alignment: .topTrailing
            )
        }
    }
}

struct OnboardingScreen: View {
    let title: String
    let text: String
    let imageName: String
    let palette: [Color]
    let cta: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            AnimatedGradientIcon(systemName: imageName, palette: palette)
            Text(title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onNext) {
                Text(cta)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}

