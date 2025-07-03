import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("HomeView")
        }
        .task {
            if AuthManager.shared.isAuthenticated {
                try? await AuthManager.shared.refreshUserProfile()
            }
        }
    }
}

#Preview {
    HomeView()
} 