import Foundation
import Network

actor RoomService {
    private let baseURL = "https://itsjustwatched.com/api/v1"
    private let session = URLSession.shared
    
    // MARK: - Room Management
    
    func fetchUserRooms(jwt: String) async throws -> [Room] {
        guard let url = URL(string: "\(baseURL)/rooms/") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        do {
            // Try to decode as direct array first
            return try JSONDecoder().decode([Room].self, from: data)
        } catch {
            // Try to decode as wrapped response
            let wrappedResponse = try JSONDecoder().decode(RoomsResponse.self, from: data)
            return wrappedResponse.rooms
        }
    }
    
    func fetchRoomDetails(roomId: String, jwt: String) async throws -> Room {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Room.self, from: data)
    }
    
    func createRoom(request: RoomCreateRequest, jwt: String) async throws -> Room {
        guard let url = URL(string: "\(baseURL)/rooms/") else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Room.self, from: data)
    }
    
    func updateRoom(roomId: String, request: RoomUpdateRequest, jwt: String) async throws -> Room {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)") else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Room.self, from: data)
    }
    
    func deleteRoom(roomId: String, jwt: String) async throws {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Participant Management
    
    func joinRoom(roomId: String, jwt: String) async throws -> Room {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/join") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Room.self, from: data)
    }
    
    func leaveRoom(roomId: String, jwt: String) async throws -> Room {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/leave") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Room.self, from: data)
    }
    
    // MARK: - Recommendations
    
    func processRecommendations(roomId: String, jwt: String) async throws -> RoomProcessResponse {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/process") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(RoomProcessResponse.self, from: data)
    }
    
    func fetchRecommendations(roomId: String, jwt: String) async throws -> RoomRecommendationsResponse {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/recommendations") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(RoomRecommendationsResponse.self, from: data)
    }
    
    func startVoting(roomId: String, jwt: String) async throws {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/start-voting") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Room Invitations
    
    func sendRoomInvitations(roomId: String, friendIds: [String], jwt: String) async throws -> RoomInviteResponse {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/invite") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let invitationRequest = RoomInvitationCreate(friendIds: friendIds)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(invitationRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(RoomInviteResponse.self, from: data)
    }
    
    func fetchMyInvitations(jwt: String) async throws -> [RoomInvitation] {
        guard let url = URL(string: "\(baseURL)/rooms/invitations") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        let invitationResponse = try JSONDecoder().decode(RoomInvitationListResponse.self, from: data)
        return invitationResponse.invitations
    }
    
    func respondToInvitation(invitationId: String, action: String, jwt: String) async throws {
        guard let url = URL(string: "\(baseURL)/rooms/invitations/\(invitationId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let response = RoomInvitationResponse(action: action)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(response)
        
        let (_, httpResponse) = try await session.data(for: request)
        
        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    func fetchRoomInvitations(roomId: String, jwt: String) async throws -> [RoomInvitation] {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/invitations") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        let invitationResponse = try JSONDecoder().decode(RoomInvitationListResponse.self, from: data)
        return invitationResponse.invitations
    }
    
    func removeRoomMember(roomId: String, memberId: String, jwt: String) async throws {
        guard let url = URL(string: "\(baseURL)/rooms/\(roomId)/members/\(memberId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 500)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - WebSocket Manager
class RoomWebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var currentMovie: RoomRecommendation?
    @Published var movieIndex: Int = 0
    @Published var totalMovies: Int = 0
    @Published var participants: [RoomParticipant] = []
    @Published var roomStatus: String = ""
    @Published var votingResult: WebSocketVotingResultMessage?
    @Published var error: String?
    
    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var pingTimer: Timer?
    
    func connect(roomId: String, jwt: String) {
        // URL encode the JWT token to handle special characters
        guard let encodedToken = jwt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            error = "Failed to encode JWT token"
            return
        }
        
        // Use the correct WebSocket URL format as per backend documentation
        let wsURL = "ws://itsjustwatched.com/api/v1/websocket/ws/\(roomId)?token=\(encodedToken)"
        
        guard let url = URL(string: wsURL) else {
            error = "Invalid WebSocket URL"
            return
        }
        
        print("🔍 Connecting to WebSocket: \(wsURL)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        // Set a timeout to check if connection is successful
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.isConnected == false {
                print("❌ WebSocket connection timeout")
                self?.error = "WebSocket connection timeout"
                self?.webSocket?.cancel()
                self?.webSocket = nil
            }
        }
        
        isConnected = true
        
        // Start listening for messages
        receiveMessage()
        
        // Start ping timer
        startPingTimer()
    }
    
    func disconnect() {
        webSocket?.cancel()
        webSocket = nil
        isConnected = false
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    func sendVote(movieId: String, vote: String) {
        let message = WebSocketVoteMessage(movieId: movieId, vote: vote)
        sendMessage(message)
    }
    
    // Note: startVoting is now handled via HTTP POST /api/v1/rooms/{roomId}/start-voting
    // This method is kept for backward compatibility but should not be used
    func startVoting() {
        print("⚠️ Warning: startVoting should be called via HTTP, not WebSocket")
    }
    
    func getRoomStatus() {
        let message = WebSocketGetRoomStatusMessage()
        sendMessage(message)
    }
    
    private func sendMessage<T: Codable>(_ message: T) {
        guard let webSocket = webSocket else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            let webSocketMessage = URLSessionWebSocketTask.Message.data(data)
            webSocket.send(webSocketMessage) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.error = "Failed to send message: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to encode message: \(error.localizedDescription)"
            }
        }
    }
    
    private func receiveMessage() {
        guard let webSocket = webSocket else { return }
        
        webSocket.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    // Continue listening
                    self?.receiveMessage()
                case .failure(let error):
                    print("❌ WebSocket receive error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("❌ Error code: \(nsError.code)")
                        print("❌ Error domain: \(nsError.domain)")
                        if let failingURL = nsError.userInfo["NSErrorFailingURLStringKey"] as? String {
                            print("❌ Failing URL: \(failingURL)")
                        }
                    }
                    self?.error = "WebSocket error: \(error.localizedDescription)"
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                // Try to decode as different message types
                if let roomState = try? JSONDecoder().decode(WebSocketRoomStateMessage.self, from: data) {
                    self.participants = roomState.participants
                    self.roomStatus = roomState.status
                } else if let currentMovie = try? JSONDecoder().decode(WebSocketCurrentMovieMessage.self, from: data) {
                    self.currentMovie = currentMovie.movie
                    self.movieIndex = currentMovie.movieIndex
                    self.totalMovies = currentMovie.totalMovies
                } else if let voteConfirmed = try? JSONDecoder().decode(WebSocketVoteConfirmedMessage.self, from: data) {
                    // Handle vote confirmation if needed
                } else if let votingResult = try? JSONDecoder().decode(WebSocketVotingResultMessage.self, from: data) {
                    self.votingResult = votingResult
                } else if let errorMessage = try? JSONDecoder().decode(WebSocketErrorMessage.self, from: data) {
                    self.error = errorMessage.message
                }
            } catch {
                self.error = "Failed to decode message: \(error.localizedDescription)"
            }
        case .string(let string):
            // Handle string messages if needed
            break
        @unknown default:
            break
        }
    }
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let message = WebSocketPingMessage(timestamp: Int(Date().timeIntervalSince1970))
        sendMessage(message)
    }
}

 