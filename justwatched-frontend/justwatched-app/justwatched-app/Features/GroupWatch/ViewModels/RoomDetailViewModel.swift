import Foundation
import SwiftUI

@MainActor
class RoomDetailViewModel: ObservableObject {
    @Published var room: Room?
    @Published var recommendations: [RoomRecommendation] = []
    @Published var invitations: [RoomInvitation] = []
    @Published var isLoading = false
    @Published var isProcessingRecommendations = false
    @Published var error: String?
    @Published var showVoting = false
    
    private let roomService = RoomService()
    private let webSocketManager = RoomWebSocketManager()
    
    var isOwner: Bool {
        guard let room = room else { return false }
        return room.ownerId == AuthManager.shared.userProfile?.id
    }
    
    var isParticipant: Bool {
        guard let room = room else { return false }
        return room.participants.contains { $0.userId == AuthManager.shared.userProfile?.id }
    }
    
    // Combined list of all invited members (participants + pending invitations, excluding declined)
    var allInvitedMembers: [InvitedMember] {
        var members: [InvitedMember] = []
        
        // Always add the room owner first (even if not in participants yet)
        if let room = room {
            let ownerInParticipants = room.participants.first { $0.userId == room.ownerId }
            let ownerName = getOwnerDisplayName(ownerId: room.ownerId, ownerInParticipants: ownerInParticipants)
            members.append(InvitedMember(
                userId: room.ownerId,
                userName: ownerName,
                status: .accepted,
                isOwner: true
            ))
        }
        
        // Add other current participants (excluding owner since we already added them)
        for participant in room?.participants ?? [] {
            if participant.userId != room?.ownerId {
                let userName = getParticipantDisplayName(participant: participant)
                members.append(InvitedMember(
                    userId: participant.userId,
                    userName: userName,
                    status: .accepted,
                    isOwner: false
                ))
            }
        }
        
        // Add pending invitations (excluding declined)
        for invitation in invitations where invitation.status == .pending {
            // Check if this user is not already a participant
            if !(room?.participants.contains { $0.userId == invitation.toUserId } ?? false) {
                members.append(InvitedMember(
                    userId: invitation.toUserId,
                    userName: invitation.toUserName,
                    status: .pending,
                    isOwner: false
                ))
            }
        }
        

        
        return members
    }
    
    // Helper function to get owner's display name (with fallback)
    private func getOwnerDisplayName(ownerId: String, ownerInParticipants: RoomParticipant?) -> String {
        // If owner is in participants list, use their display name
        if let ownerParticipant = ownerInParticipants, let displayName = ownerParticipant.displayName, !displayName.isEmpty {
            return displayName
        }
        
        // If current user is the owner, use their profile name
        if ownerId == AuthManager.shared.userProfile?.id {
            return AuthManager.shared.userProfile?.displayName ?? "You"
        }
        
        // Fallback to a generic name if no display name available
        return "Room Owner"
    }
    
    // Helper function to get participant's display name (with fallback)
    private func getParticipantDisplayName(participant: RoomParticipant) -> String {
        // If display name is available, use it
        if let displayName = participant.displayName, !displayName.isEmpty {
            return displayName
        }
        
        // If current user is the participant, use their profile name
        if participant.userId == AuthManager.shared.userProfile?.id {
            return AuthManager.shared.userProfile?.displayName ?? "You"
        }
        
        // Fallback to a generic name if no display name available
        return "User \(String(participant.userId.prefix(8)))"
    }
    
    func fetchRoomDetails(roomId: String, jwt: String) async {
        isLoading = true
        self.error = nil
        
        do {
            room = try await roomService.fetchRoomDetails(roomId: roomId, jwt: jwt)
            

            
            // Also fetch invitations for this room
            await fetchRoomInvitations(roomId: roomId, jwt: jwt)
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to fetch room details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchRecommendations(roomId: String, jwt: String) async {
        do {
            let response = try await roomService.fetchRecommendations(roomId: roomId, jwt: jwt)
            recommendations = response.recommendations
        } catch let networkError as NetworkError {
            if networkError.errorDescription?.contains("404") == true {
                // No recommendations yet, this is normal
                recommendations = []
            } else {
                self.error = networkError.localizedDescription ?? "Network error occurred"
            }
        } catch let error {
            self.error = "Failed to fetch recommendations: \(error.localizedDescription)"
        }
    }
    
    func processRecommendations(roomId: String, jwt: String) async {
        isProcessingRecommendations = true
        self.error = nil
        
        do {
            let response = try await roomService.processRecommendations(roomId: roomId, jwt: jwt)
            
            // Wait a bit for processing to complete, then fetch results
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await fetchRecommendations(roomId: roomId, jwt: jwt)
            
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to process recommendations: \(error.localizedDescription)"
        }
        
        isProcessingRecommendations = false
    }
    
    func startVoting(roomId: String, jwt: String) {
        webSocketManager.connect(roomId: roomId, jwt: jwt)
        showVoting = true
    }
    
    func stopVoting() {
        webSocketManager.disconnect()
        showVoting = false
    }
    
    func sendVote(movieId: String, vote: String) {
        webSocketManager.sendVote(movieId: movieId, vote: vote)
    }
    
    func startVotingSession(roomId: String, jwt: String) async {
        // Check if user is the room owner
        guard isOwner else {
            self.error = "Only room owners can start voting sessions"
            return
        }
        
        do {
            try await roomService.startVoting(roomId: roomId, jwt: jwt)
            print("✅ Voting session started successfully")
            // Open the voting UI for the owner as well
            startVoting(roomId: roomId, jwt: jwt)
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Failed to start voting session"
        } catch let error {
            self.error = "Failed to start voting session: \(error.localizedDescription)"
        }
    }
    
    func fetchRoomInvitations(roomId: String, jwt: String) async {
        do {
            invitations = try await roomService.fetchRoomInvitations(roomId: roomId, jwt: jwt)
            

        } catch {
            // Don't show error for invitations, just log it
            print("Failed to fetch room invitations: \(error)")
            invitations = []
        }
    }
    
    // MARK: - WebSocket Observers
    
    var webSocketManagerInstance: RoomWebSocketManager {
        return webSocketManager
    }
    
    var currentMovie: RoomRecommendation? {
        return webSocketManager.currentMovie
    }
    
    var movieIndex: Int {
        return webSocketManager.movieIndex
    }
    
    var totalMovies: Int {
        return webSocketManager.totalMovies
    }
    
    var participants: [RoomParticipant] {
        return webSocketManager.participants
    }
    
    var roomStatus: String {
        return webSocketManager.roomStatus
    }
    
    var votingResult: WebSocketVotingResultMessage? {
        return webSocketManager.votingResult
    }
    
    var webSocketError: String? {
        return webSocketManager.error
    }
    
    var isWebSocketConnected: Bool {
        return webSocketManager.isConnected
    }
    
    // MARK: - Helper Methods
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd MMM yyyy"
            displayFormatter.locale = Locale(identifier: "en_US")
            return displayFormatter.string(from: date)
        }
        
        // Fallback: try parsing with a more flexible approach
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        inputFormatter.locale = Locale(identifier: "en_US")
        
        if let date = inputFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd MMM yyyy"
            displayFormatter.locale = Locale(identifier: "en_US")
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    func getStatusColor(_ status: RoomStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .processing:
            return .yellow
        case .completed:
            return .blue
        case .inactive:
            return .gray
        }
    }
} 