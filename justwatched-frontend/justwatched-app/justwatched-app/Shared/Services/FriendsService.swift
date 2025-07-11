import Foundation

// MARK: - Models
struct FriendStatusResponse: Codable {
    let user_id: String
    let status: String // "not_friends" | "pending_sent" | "pending_received" | "friends"
}

struct FriendRequest: Codable, Identifiable {
    let request_id: String
    let from_user_id: String
    let to_user_id: String
    let status: String // "pending_sent" | "pending_received"
    let created_at: String
    let responded_at: String?
    var id: String { request_id }
}

struct FriendRequestPayload: Codable {
    let to_user_id: String
}

struct Friend: Codable, Identifiable {
    let user_id: String
    let display_name: String
    let color: String
    var id: String { user_id }
}

// MARK: - Service
actor FriendsService {
    static let shared = FriendsService()
    private let baseURL = "https://itsjustwatched.com/api/v1/friends"
    private var jwt: String? { AuthManager.shared.jwt }
    private var session: URLSession { .shared }

    // 1. Check friendship status
    func checkStatus(with userId: String) async throws -> FriendStatusResponse {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/status/\(userId)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(FriendStatusResponse.self, from: data)
    }

    // 2. Send friend request
    func sendRequest(to userId: String) async throws -> FriendRequest {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/requests")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = FriendRequestPayload(to_user_id: userId)
        
        // Debug: Print request details
        print("🔍 Sending friend request to: \(url)")
        print("🔍 Request body: \(body)")
        
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        
        // Debug: Print response details
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 Friend request response status: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 Friend request response body: \(responseString)")
        }
        
        return try JSONDecoder().decode(FriendRequest.self, from: data)
    }

    // 3. Get pending friend requests
    struct FriendRequestsResponse: Codable { let requests: [FriendRequest]; let total_count: Int }
    func getPendingRequests() async throws -> [FriendRequest] {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/requests")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(FriendRequestsResponse.self, from: data).requests
    }

    // 4. Respond to friend request
    func respondToRequest(requestId: String, action: String) async throws {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/requests/\(requestId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["request_id": requestId, "action": action]
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await session.data(for: req)
    }

    // 5. Get current user's friends
    struct FriendsListResponse: Codable { let friends: [Friend]; let total_count: Int }
    func getFriends() async throws -> [Friend] {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: baseURL + "/")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(FriendsListResponse.self, from: data).friends
    }

    // 6. Remove friend
    func removeFriend(userId: String) async throws {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/\(userId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: req)
    }

    // 7. Get another user's friends (if friends)
    func getFriendsOfUser(userId: String) async throws -> [Friend] {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)/users/\(userId)/friends")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(FriendsListResponse.self, from: data).friends
    }
} 