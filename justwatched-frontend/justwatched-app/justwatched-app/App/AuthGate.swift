import SwiftUI

struct AuthGate: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("isNewUser") var isNewUser: Bool = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if isNewUser && !hasSeenOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            authManager.loadFromStorage()
        }
    }
}

#Preview {
    AuthGate()
} 