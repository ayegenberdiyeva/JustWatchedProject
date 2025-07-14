import SwiftUI

struct RoomDetailView: View {
    let roomId: String
    @StateObject private var viewModel = RoomDetailViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToVoting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                                    ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    errorSection(error: error)
                } else if let room = viewModel.room {
                    ScrollView {
                        VStack(spacing: 24) {
                            roomHeaderSection(room: room)
                            participantsSection(room: room)
                            recommendationsSection(room: room)
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Room Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let jwt = authManager.jwt {
                            Task { await viewModel.fetchRoomDetails(roomId: roomId, jwt: jwt) }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                if let jwt = authManager.jwt {
                    Task {
                        await viewModel.fetchRoomDetails(roomId: roomId, jwt: jwt)
                        await viewModel.fetchRecommendations(roomId: roomId, jwt: jwt)
                    }
                }
            }
            .onChange(of: viewModel.showVoting) { show in
                if show { navigateToVoting = true }
            }
            NavigationLink(destination: VotingView(viewModel: viewModel, roomId: roomId), isActive: $navigateToVoting) { EmptyView() }
        }
    }
    
    private func roomHeaderSection(room: Room) -> some View {
        ZStack {
            let colorValue = AuthManager.shared.userProfile?.color ?? "red"
            AnimatedPaletteGradientBackground(paletteName: colorValue)
                .cornerRadius(32)
                .overlay(Color.black.opacity(0.5).cornerRadius(32))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        if let description = room.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: room.status)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(room.currentParticipants)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Participants")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(room.maxParticipants)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.formatDate(room.createdAt))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                
                // Action Buttons
                if viewModel.isOwner {
                    ownerActionButtons(room: room)
                } else if viewModel.isParticipant {
                    participantActionButtons(room: room)
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
    
    @State private var showInviteFriends = false
    @State private var showInvitations = false
    
    private func ownerActionButtons(room: Room) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if room.status == .active && !viewModel.recommendations.isEmpty {
                    Button("Start Voting") {
                        if let jwt = authManager.jwt {
                            Task { await viewModel.startVotingSession(roomId: roomId, jwt: jwt) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(preferredColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                if room.status == .active && viewModel.recommendations.isEmpty {
                    Button("Generate Recommendations") {
                        if let jwt = authManager.jwt {
                            Task { await viewModel.processRecommendations(roomId: roomId, jwt: jwt) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(preferredColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Invitation Management Buttons
            HStack(spacing: 12) {
                Button("Invite Friends") {
                    showInviteFriends = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Button("View Invitations") {
                    showInvitations = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(roomId: roomId, roomName: room.name)
        }
        .sheet(isPresented: $showInvitations) {
            RoomInvitationsManagementView(roomId: roomId, roomName: room.name)
        }
    }
    
    private func participantActionButtons(room: Room) -> some View {
        HStack(spacing: 12) {
            if room.status == .active && !viewModel.recommendations.isEmpty {
                Button("Join Voting") {
                    if let jwt = authManager.jwt {
                        viewModel.startVoting(roomId: roomId, jwt: jwt)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(preferredColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    @State private var showRemoveMemberAlert = false
    @State private var memberToRemove: RoomParticipant?
    
    private func participantsSection(room: Room) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Participants")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(room.participants) { participant in
                        ParticipantCard(
                            participant: participant,
                            isOwner: room.ownerId == authManager.userProfile?.id,
                            onRemove: {
                                memberToRemove = participant
                                showRemoveMemberAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .alert("Remove Member", isPresented: $showRemoveMemberAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove, let jwt = authManager.jwt {
                    Task { await removeMember(roomId: room.roomId, memberId: member.userId, jwt: jwt) }
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.displayName ?? "this member") from the room?")
            }
        }
    }
    
    private func removeMember(roomId: String, memberId: String, jwt: String) async {
        do {
            try await RoomService().removeRoomMember(roomId: roomId, memberId: memberId, jwt: jwt)
            // Refresh room details after removing member
            await viewModel.fetchRoomDetails(roomId: roomId, jwt: jwt)
        } catch {
            print("Error removing member: \(error)")
        }
    }
    
    private func recommendationsSection(room: Room) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommendations")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                if viewModel.isProcessingRecommendations {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if viewModel.recommendations.isEmpty {
                emptyRecommendationsSection
            } else {
                recommendationsList
            }
        }
    }
    
    private var emptyRecommendationsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No recommendations yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Generate AI-powered recommendations based on participants' taste profiles")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private var recommendationsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.recommendations) { recommendation in
                    RoomRecommendationCard(recommendation: recommendation)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func errorSection(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Error loading room")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Retry") {
                if let jwt = authManager.jwt {
                    Task { await viewModel.fetchRoomDetails(roomId: roomId, jwt: jwt) }
                }
            }
            .padding()
            .background(Color.white.opacity(0.15))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
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
}

struct ParticipantCard: View {
    let participant: RoomParticipant
    let isOwner: Bool
    let onRemove: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: "393B3D").opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if participant.isOwner {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            
            Text(participant.displayName ?? "Unknown")
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Remove button for room owners (only for non-owners)
            if isOwner && !participant.isOwner, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(width: 80)
    }
}

struct RoomRecommendationCard: View {
    let recommendation: RoomRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let posterPath = recommendation.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w200")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 180)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text("Score: \(Int(recommendation.groupScore * 100))%")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 120)
    }
}

#Preview {
    RoomDetailView(roomId: "test-room")
} 