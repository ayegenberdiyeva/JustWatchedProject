import SwiftUI

struct AuthGate: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
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