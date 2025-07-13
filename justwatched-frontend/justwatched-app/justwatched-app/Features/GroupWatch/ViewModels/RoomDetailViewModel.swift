import Foundation
import SwiftUI

@MainActor
class RoomDetailViewModel: ObservableObject {
    @Published var room: Room?
    @Published var recommendations: [RoomRecommendation] = []
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
    
    func fetchRoomDetails(roomId: String, jwt: String) async {
        isLoading = true
        self.error = nil
        
        do {
            room = try await roomService.fetchRoomDetails(roomId: roomId, jwt: jwt)
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
    
    func startVotingSession() {
        webSocketManager.startVoting()
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
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
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