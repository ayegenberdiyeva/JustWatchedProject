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
    @State private var pendingFriendRequestsCount = 0
    // Map string color to SwiftUI Color
    private func preferredColor() -> Color {
        switch authManager.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .red
        }
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            Group {
                if pendingFriendRequestsCount > 0 {
                    FriendsFeedView()
                        .tabItem {
                            Label("Friends", systemImage: "person.2.fill")
                        }
                        .badge(pendingFriendRequestsCount)
                } else {
                    FriendsFeedView()
                        .tabItem {
                            Label("Friends", systemImage: "person.2.fill")
                        }
                }
            }
            
            // AddReviewView()
            //     .tabItem {
            //         Label("Add Review", systemImage: "plus")
            //     }
            
            Group {
                if pendingInvitationsCount > 0 {
                    RoomListView()
                        .tabItem {
                            Label("Rooms", systemImage: "sparkles")
                        }
                        .badge(pendingInvitationsCount)
                } else {
                    RoomListView()
                        .tabItem {
                            Label("Rooms", systemImage: "sparkles")
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
            await loadPendingFriendRequests()
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task { 
                    await loadPendingInvitations()
                    await loadPendingFriendRequests()
                }
            } else {
                pendingInvitationsCount = 0
                pendingFriendRequestsCount = 0
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
    
    private func loadPendingFriendRequests() async {
        guard authManager.isAuthenticated else {
            pendingFriendRequestsCount = 0
            return
        }
        
        do {
            let pendingRequests = try await FriendsService.shared.getPendingRequests()
            let incomingRequests = pendingRequests.filter { $0.status == "pending_received" }
            await MainActor.run {
                pendingFriendRequestsCount = incomingRequests.count
            }
        } catch {
            // Check if this is a cancellation error and ignore it
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Request was cancelled, this is normal when view disappears or multiple requests are made
                return
            }
            print("Error loading pending friend requests: \(error)")
            await MainActor.run {
                pendingFriendRequestsCount = 0
            }
        }
    }
}

#Preview {
    MainTabView()
}
