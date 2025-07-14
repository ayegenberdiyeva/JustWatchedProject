import SwiftUI

struct InviteFriendsView: View {
    let roomId: String
    let roomName: String
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserSearchResult] = []
    @State private var selectedFriends: Set<String> = []
    @State private var isLoading = false
    @State private var isInviting = false
    @State private var error: String? = nil
    @State private var successMessage: String? = nil
    
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
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Invite Friends")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("to \(roomName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Friends List
                    if friends.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No friends found")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Add some friends first to invite them to your room!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(friends) { friend in
                                    FriendSelectionRow(
                                        friend: friend,
                                        isSelected: selectedFriends.contains(friend.user_id),
                                        preferredColor: preferredColor,
                                        onToggle: {
                                            if selectedFriends.contains(friend.user_id) {
                                                selectedFriends.remove(friend.user_id)
                                            } else {
                                                selectedFriends.insert(friend.user_id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Success Message
                    if let successMessage = successMessage {
                        Text(successMessage)
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    // Error Message
                    if let error = error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 20) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        
                        Button(action: {
                            Task { await sendInvitations() }
                        }) {
                            HStack {
                                if isInviting {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane")
                                }
                                Text("Send Invites")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedFriends.isEmpty ? Color.gray : preferredColor)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                        }
                        .disabled(selectedFriends.isEmpty || isInviting)
                        .opacity(selectedFriends.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadFriends()
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        error = nil
        
        do {
            guard let jwt = AuthManager.shared.jwt else {
                throw NetworkError.invalidURL
            }
            // Load friends using the existing friends service
            let friendList = try await FriendsService.shared.getFriends()
            // Convert Friend objects to UserSearchResult objects
            friends = friendList.map { friend in
                UserSearchResult(
                    user_id: friend.user_id,
                    display_name: friend.display_name,
                    color: friend.color,
                    is_friend: true,
                    friend_status: "friends"
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func sendInvitations() async {
        isInviting = true
        error = nil
        successMessage = nil
        
        do {
            guard let jwt = AuthManager.shared.jwt else {
                throw NetworkError.invalidURL
            }
            
            let friendIds = Array(selectedFriends)
            let response = try await RoomService().sendRoomInvitations(roomId: roomId, friendIds: friendIds, jwt: jwt)
            
            successMessage = "Successfully sent \(response.createdInvitations) invitation(s)!"
            
            // Clear selection after successful invitation
            selectedFriends.removeAll()
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isInviting = false
    }
}

// MARK: - Friend Selection Row
struct FriendSelectionRow: View {
    let friend: UserSearchResult
    let isSelected: Bool
    let preferredColor: Color
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.display_name)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? preferredColor : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? preferredColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    NavigationStack {
        InviteFriendsView(roomId: "room123", roomName: "Movie Night")
    }
} 