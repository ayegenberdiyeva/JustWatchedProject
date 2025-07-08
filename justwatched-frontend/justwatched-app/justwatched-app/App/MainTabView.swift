import SwiftUI

struct MainTabView: View {
    @State private var showAddReview = false
    @ObservedObject private var authManager = AuthManager.shared

    // Map string color to SwiftUI Color
    private func preferredColor() -> Color {
        switch authManager.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            FriendsFeedView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
            
            AddReviewView()
                .tabItem {
                    Label("Add Review", systemImage: "plus")
                }
            
            LobbyView()
                .tabItem {
                    Label("Room", systemImage: "person.3.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(preferredColor())
        .toolbarBackground(Color.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }
}

#Preview {
    MainTabView()
}
