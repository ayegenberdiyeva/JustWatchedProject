import SwiftUI

struct RoomInvitationsManagementView: View {
    let roomId: String
    let roomName: String
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
                    VStack(spacing: 8) {
                        Text("Room Invitations")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("for \(roomName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Invitations List
                    if invitations.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No invitations")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("No invitations have been sent for this room yet!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(invitations) { invitation in
                                    InvitationManagementCard(
                                        invitation: invitation,
                                        receiverName: invitation.toUserName,
                                        preferredColor: preferredColor
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
    }
    
    private func loadInvitations() async {
        isLoading = true
        error = nil
        
        do {
            guard let jwt = AuthManager.shared.jwt else {
                throw NetworkError.invalidURL
            }
            invitations = try await RoomService().fetchRoomInvitations(roomId: roomId, jwt: jwt)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Invitation Management Card
struct InvitationManagementCard: View {
    let invitation: RoomInvitation
    let receiverName: String
    let preferredColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(receiverName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(invitation.status.displayName)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Invited:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatDate(invitation.createdAt))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                if let respondedAt = invitation.respondedAt {
                    HStack {
                        Text("Responded:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatDate(respondedAt))
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    NavigationStack {
        RoomInvitationsManagementView(roomId: "room123", roomName: "Movie Night")
    }
} 