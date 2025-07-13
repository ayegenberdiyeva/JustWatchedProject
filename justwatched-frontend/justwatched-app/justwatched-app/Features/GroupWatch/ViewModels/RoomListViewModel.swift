import Foundation
import SwiftUI

@MainActor
class RoomListViewModel: ObservableObject {
    @Published var rooms: [Room] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showCreateRoom = false
    @Published var successMessage: String? = nil
    @Published var deletingRoomId: String? = nil
    
    private let roomService = RoomService()
    
    func fetchRooms(jwt: String) async {
        isLoading = true
        self.error = nil
        
        do {
            rooms = try await roomService.fetchUserRooms(jwt: jwt)
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to fetch rooms: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createRoom(name: String, description: String?, maxParticipants: Int, jwt: String) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let request = RoomCreateRequest(
                name: name,
                description: description,
                maxParticipants: maxParticipants
            )
            
            let newRoom = try await roomService.createRoom(request: request, jwt: jwt)
            rooms.append(newRoom)
            isLoading = false
            return true
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to create room: \(error.localizedDescription)"
        }
        
        isLoading = false
        return false
    }
    
    func deleteRoom(roomId: String, jwt: String) async {
        deletingRoomId = roomId
        defer { deletingRoomId = nil }
        do {
            try await roomService.deleteRoom(roomId: roomId, jwt: jwt)
            // After deletion, reload rooms and set success message
            await fetchRooms(jwt: jwt)
            self.successMessage = "Room deleted successfully."
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to delete room: \(error.localizedDescription)"
        }
    }
    
    func joinRoom(roomId: String, jwt: String) async {
        do {
            let updatedRoom = try await roomService.joinRoom(roomId: roomId, jwt: jwt)
            if let index = rooms.firstIndex(where: { $0.roomId == roomId }) {
                rooms[index] = updatedRoom
            } else {
                rooms.append(updatedRoom)
            }
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to join room: \(error.localizedDescription)"
        }
    }
    
    func leaveRoom(roomId: String, jwt: String) async {
        do {
            let updatedRoom = try await roomService.leaveRoom(roomId: roomId, jwt: jwt)
            if let index = rooms.firstIndex(where: { $0.roomId == roomId }) {
                rooms[index] = updatedRoom
            }
        } catch let networkError as NetworkError {
            self.error = networkError.localizedDescription ?? "Network error occurred"
        } catch let error {
            self.error = "Failed to leave room: \(error.localizedDescription)"
        }
    }
    
    var isOwner: (Room) -> Bool {
        return { room in
            room.ownerId == AuthManager.shared.userProfile?.id
        }
    }
    
    var isParticipant: (Room) -> Bool {
        return { room in
            room.participants.contains { $0.userId == AuthManager.shared.userProfile?.id }
        }
    }
} 