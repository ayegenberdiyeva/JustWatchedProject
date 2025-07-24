import SwiftUI

struct FriendsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var selectedTab = 0
    @State private var navigateToProfile = false
    @State private var selectedUserId: String = ""
    
    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .red
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("View", selection: $selectedTab) {
                        Text("Friends (\(viewModel.friends.count))").tag(0)
                        Text("Requests (\(viewModel.incomingRequests.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .accentColor(preferredColor)
                    .colorScheme(.dark)
                    .onChange(of: selectedTab) { _, _ in
                        Task {
                            if selectedTab == 0 {
                                await viewModel.loadFriends()
                            } else {
                                await viewModel.loadPendingRequests()
                            }
                        }
                    }
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Spacer()
                    } else {
                        TabView(selection: $selectedTab) {
                            // Friends Tab
                            friendsList
                                .tag(0)
                            
                            // Requests Tab
                            requestsList
                                .tag(1)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            if selectedTab == 0 {
                                await viewModel.loadFriends()
                            } else {
                                await viewModel.loadPendingRequests()
                                await loadPendingFriendRequests()
                            }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .task {
                await viewModel.loadFriends()
                await loadPendingFriendRequests()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                OtherUserProfileView(userId: selectedUserId)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func loadPendingFriendRequests() async {
        do {
            let pendingRequests = try await FriendsService.shared.getPendingRequests()
            let incomingRequests = pendingRequests.filter { $0.status == "pending_received" }
            await MainActor.run {
                viewModel.incomingRequests = incomingRequests
            }
        } catch {
            // Check if this is a cancellation error and ignore it
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Request was cancelled, this is normal when view disappears or multiple requests are made
                return
            }
            print("Error loading pending friend requests: \(error)")
        }
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No friends yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Add friends to see their reviews and collections")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ForEach(viewModel.friends) { friend in
                        FriendRowView(friend: friend, preferredColor: preferredColor) { userId in
                            selectedUserId = userId
                            navigateToProfile = true
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.incomingRequests.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No pending requests")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("You don't have any incoming friend requests")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ForEach(viewModel.incomingRequests) { request in
                        FriendRequestRowView(
                            request: request,
                            displayName: viewModel.userDisplayNames[request.from_user_id] ?? request.from_user_id,
                            preferredColor: preferredColor,
                            onAccept: {
                                Task { await viewModel.respondToRequest(requestId: request.request_id, action: "accept") }
                            },
                            onDecline: {
                                Task { await viewModel.respondToRequest(requestId: request.request_id, action: "decline") }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FriendRowView: View {
    let friend: Friend
    let preferredColor: Color
    let onNavigateToProfile: (String) -> Void
    
    var body: some View {
        Button(action: {
            onNavigateToProfile(friend.user_id)
        }) {
            HStack(spacing: 12) {
                // Friend avatar/color indicator
                // Circle()
                //     .fill(Color(friend.color))
                //     .frame(width: 40, height: 40)
                //     .overlay(
                //         Text(friend.display_name.prefix(1).uppercased())
                //             .font(.headline)
                //             .fontWeight(.bold)
                //             .foregroundColor(.white)
                //     )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.display_name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(hex: "393B3D").opacity(0.3))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FriendRequestRowView: View {
    let request: FriendRequest
    let displayName: String
    let preferredColor: Color
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isResponding = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // User avatar placeholder
//                Circle()
//                    .fill(Color.gray)
//                    .frame(width: 40, height: 40)
//                    .overlay(
//                        Text(displayName.prefix(1).uppercased())
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .foregroundColor(.white)
//                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Wants to be your friend")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    isResponding = true
                    onAccept()
                }) {
                    Text("Accept")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .disabled(isResponding)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    isResponding = true
                    onDecline()
                }) {
                    Text("Decline")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary)
                        .cornerRadius(12)
                }
                .disabled(isResponding)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
    }
}

#Preview {
    FriendsListView()
} 
