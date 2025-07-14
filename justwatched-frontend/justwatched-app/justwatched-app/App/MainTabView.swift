import SwiftUI

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MainTabView: View {
    @State private var showAddReview = false
    @ObservedObject private var authManager = AuthManager.shared
    @State private var pendingInvitationsCount = 0
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
            
            Group {
                if pendingInvitationsCount > 0 {
                    RoomListView()
                        .tabItem {
                            Label("Group Watch", systemImage: "person.3.fill")
                        }
                        .badge(pendingInvitationsCount)
                } else {
                    RoomListView()
                        .tabItem {
                            Label("Group Watch", systemImage: "person.3.fill")
                        }
                }
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
        .task {
            await loadPendingInvitations()
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task { await loadPendingInvitations() }
            } else {
                pendingInvitationsCount = 0
            }
        }
    }
    
    private func loadPendingInvitations() async {
        guard authManager.isAuthenticated, let jwt = authManager.jwt else {
            pendingInvitationsCount = 0
            return
        }
        
        do {
            let invitations = try await RoomService().fetchMyInvitations(jwt: jwt)
            let pendingCount = invitations.filter { $0.status == .pending }.count
            await MainActor.run {
                pendingInvitationsCount = pendingCount
            }
        } catch {
            print("Error loading pending invitations: \(error)")
            await MainActor.run {
                pendingInvitationsCount = 0
            }
        }
    }
}

#Preview {
    MainTabView()
}
