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
        
        guard httpResponse.statusCode == 204 else {
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
        guard let url = URL(string: "wss://itsjustwatched.com/api/v1/websocket/ws/\(roomId)?token=\(jwt)") else {
            error = "Invalid WebSocket URL"
            return
        }
        
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
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
    
    func startVoting() {
        let message = WebSocketStartVotingMessage()
        sendMessage(message)
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

 