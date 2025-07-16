import SwiftUI

struct OtherUserProfileView: View {
    let userId: String
    @StateObject private var viewModel = OtherUserProfileViewModel()
    @StateObject private var friendVM = ProfileFriendViewModel()
    @StateObject private var friendListVM = FriendsListViewModel()
    
    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if let error = viewModel.error {
                    Text(error).foregroundColor(.red).padding()
                } else if let profile = viewModel.userProfile {
                    ScrollView {
                        VStack(spacing: 24) {
                            profileHeader(profile: profile)
                            friendActionButtons(userId: userId)
                            statsCard(profile: profile)
                            if !(profile.isFriend ?? false) {
                                Text("Add this user as a friend to see their reviews and to add them to rooms.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            // Optionally, add reviews, friends, etc.
                        }
                        .padding(.top)
                    }
                }
            }
            // .navigationTitle(viewModel.userProfile?.displayName ?? "User Profile")
            .task { await viewModel.fetchUserProfile(userId: userId) }
        }
    }
    
    private func profileHeader(profile: UserProfile) -> some View {
        ZStack {
            let colorValue = profile.color ?? "red"
            AnimatedPaletteGradientBackground(paletteName: colorValue)
                .cornerRadius(32)
                .overlay(Color.black.opacity(0.5).cornerRadius(32))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    // Text("Hi, ")
                    //     .font(.title2)
                    //     .foregroundColor(.white)
                    Text(profile.displayName ?? "UserName")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                
                // Show bio only if users are friends
                if let isFriend = profile.isFriend, isFriend {
                    Text((profile.bio ?? "").prefix(80))
                        .font(.footnote)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Add as friend to see their bio")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private func statsCard(profile: UserProfile) -> some View {
        HStack(spacing: 0) {
            if let isFriend = profile.isFriend, isFriend {
                // Show actual stats for friends
                statView(title: "Reviews", value: "-") // TODO: Fetch actual review count
                Divider().frame(height: 40).background(Color(hex: "393B3D"))
                statView(title: "Watchlist", value: "-") // TODO: Fetch actual watchlist count
                Divider().frame(height: 40).background(Color(hex: "393B3D"))
                statView(title: "Friends", value: "-") // TODO: Fetch actual friends count
            } else {
                // Show placeholder for non-friends
                statView(title: "Reviews", value: "?")
                Divider().frame(height: 40).background(Color(hex: "393B3D"))
                statView(title: "Watchlist", value: "?")
                Divider().frame(height: 40).background(Color(hex: "393B3D"))
                statView(title: "Friends", value: "?")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "393B3D"))
        }
        .frame(maxWidth: .infinity)
    }
    
    // --- FRIEND ACTION BUTTONS ---
    @ViewBuilder
    private func friendActionButtons(userId: String) -> some View {
        VStack(spacing: 8) {
            if let error = friendVM.error {
                Text(error).foregroundColor(.red)
            }
            if friendVM.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else {
                // Use the isFriend status from the profile response if available
                let isFriendFromProfile = viewModel.userProfile?.isFriend ?? false
                let currentStatus = friendVM.friendStatus ?? (isFriendFromProfile ? "friends" : "not_friends")
                
                switch currentStatus {
                case "not_friends":
                    Button("Add Friend") {
                        Task { await friendVM.sendRequest(to: userId) }
                    }
                    // .buttonStyle(.borderedProminent)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                case "pending_sent":
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("Request sent")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if friendListVM.isLoading {
                            Text("Canceling...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Button("Cancel?") {
                                if let reqId = friendVM.pendingRequestId {
                                    Task {
                                        await friendListVM.cancelSentRequest(requestId: reqId)
                                        friendVM.friendStatus = "not_friends"
                                        friendVM.pendingRequestId = nil
                                    }
                                }
                            }
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(preferredColor)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .cornerRadius(16)
                case "pending_received":
                    HStack(spacing: 12) {
                        Button("Accept") {
                            if let reqId = friendVM.pendingRequestId {
                                Task { await friendVM.respondToRequest(requestId: reqId, action: "accept") }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                        Button("Decline") {
                            if let reqId = friendVM.pendingRequestId {
                                Task { await friendVM.respondToRequest(requestId: reqId, action: "decline") }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePrimaryGrey)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                case "friends":
                    if friendVM.isLoading {
                        Button("Removing...") {}
                            .disabled(true)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themePrimaryGrey)
                            .foregroundColor(.white.opacity(0.6))
                            .cornerRadius(16)
                    } else {
                        Button("Remove Friend") {
                            Task { await friendVM.removeFriend(userId: userId) }
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePrimaryGrey)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                default:
                    EmptyView()
                    .frame(height: 44)
                }
            }
        }
        .onAppear {
            Task { await friendVM.checkStatus(with: userId) }
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .tabBar)
    }
} 