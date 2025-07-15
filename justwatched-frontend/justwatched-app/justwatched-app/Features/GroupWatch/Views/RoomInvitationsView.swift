import SwiftUI

struct RoomInvitationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var invitations: [RoomInvitation] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    
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
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Error loading invitations")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadInvitations() }
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Room Invitations")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    
                    // Invitations List
                    if invitations.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No invitations")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("You don't have any pending room invitations!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(invitations.filter { $0.status == .pending }) { invitation in
                                    InvitationCard(
                                        invitation: invitation,
                                        preferredColor: preferredColor,
                                        onAccept: {
                                            Task { await respondToInvitation(invitation, action: "accept") }
                                        },
                                        onDecline: {
                                            Task { await respondToInvitation(invitation, action: "decline") }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadInvitations()
        }
        .toolbar(.hidden, for: .tabBar)

    }
    
    private func loadInvitations() async {
        isLoading = true
        error = nil
        
        do {
            guard let jwt = AuthManager.shared.jwt else {
                throw NetworkError.invalidURL
            }
            invitations = try await RoomService().fetchMyInvitations(jwt: jwt)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func respondToInvitation(_ invitation: RoomInvitation, action: String) async {
        do {
            guard let jwt = AuthManager.shared.jwt else {
                throw NetworkError.invalidURL
            }
            try await RoomService().respondToInvitation(invitationId: invitation.invitationId, action: action, jwt: jwt)
            
            // Remove the invitation from the local list
            await MainActor.run {
                invitations.removeAll { $0.invitationId == invitation.invitationId }
            }
            
            // If accepted, dismiss the view to go back to room list
            if action == "accept" {
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            print("Error responding to invitation: \(error)")
        }
    }
}

// MARK: - Invitation Card
struct InvitationCard: View {
    let invitation: RoomInvitation
    let preferredColor: Color
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isResponding = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Room Info
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.roomName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let description = invitation.roomDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("From:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(invitation.fromUserName)
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Text(invitation.status.displayName)
                    //     .font(.caption)
                    //     .foregroundColor(statusColor)
                    //     .padding(.horizontal, 8)
                    //     .padding(.vertical, 2)
                    //     .background(statusColor.opacity(0.2))
                    //     .cornerRadius(8)
                }
            }
            
                            // Action Buttons (only show for pending invitations)
                if invitation.status == .pending {
                    HStack(spacing: 16) {
                        Button(action: {
                            isResponding = true
                            onAccept()
                        }) {
                            Text("Accept")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
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
                                .padding(.horizontal, 20)
                                .background(Color.secondary)
                                .cornerRadius(12)
                        }
                        .disabled(isResponding)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
    }
    
    private var statusColor: Color {
        switch invitation.status {
        case .pending: return .yellow
        case .accepted: return .green
        case .declined: return .red
        }
    }
}

#Preview {
    NavigationStack {
        RoomInvitationsView()
    }
} 