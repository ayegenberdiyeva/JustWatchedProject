import SwiftUI

struct LobbyView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("LobbyView")
        }
        .task {
            if AuthManager.shared.isAuthenticated {
                try? await AuthManager.shared.refreshUserProfile()
            }
        }
    }
}

#Preview {
    LobbyView()
} 