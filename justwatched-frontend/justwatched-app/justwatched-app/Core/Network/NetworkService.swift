import Foundation

struct EmptyResponse: Codable {}

struct AuthResponse: Codable {
    let access_token: String
    let user_id: String
}

struct APIError: Codable, LocalizedError {
    let detail: String
    var errorDescription: String? { detail }
}

struct UserProfileRequest: Encodable {
    let display_name: String?
    let email: String?
    let bio: String?
    let avatar_url: String?
}

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided was invalid."
        case .requestFailed(let code): return "The network request failed with status code \(code)."
        case .decodingFailed: return "Failed to decode the server response."
        case .invalidResponse: return "Invalid response from server."
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "http://localhost:8000/api/v1"
    private let authManager = AuthManager.shared
    
    private init() {}
    
    private func authorizedRequest(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let token = authManager.jwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return try await URLSession.shared.data(for: request)
    }
    
    func fetchProfile() async throws -> UserProfile {
        let (data, response) = try await authorizedRequest("/users/me")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    func updateProfile(displayName: String?, email: String?, bio: String?, avatarUrl: String?) async throws {
        let parameters: [String: Any?] = [
            "display_name": displayName,
            "email": email,
            "bio": bio,
            "avatar_url": avatarUrl
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: parameters.compactMapValues { $0 })
        
        let (_, response) = try await authorizedRequest("/users/me", method: "PATCH", body: jsonData)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func fetchUserReviews() async throws -> [Review] {
        let (data, response) = try await authorizedRequest("/users/me/reviews")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Review].self, from: data)
    }
    
    func postReview(review: ReviewRequest) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(review)
        
        let (_, response) = try await authorizedRequest("/reviews", method: "POST", body: jsonData)
        
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func searchMovies(query: String) async throws -> [Movie] {
        guard var urlComponents = URLComponents(string: baseURL + "/movies/search") else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = authManager.jwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode([Movie].self, from: data)
    }

    // New TMDB-style search for MovieSearchResult
    func searchMoviesV2(query: String) async throws -> [MovieSearchResult] {
        guard var urlComponents = URLComponents(string: baseURL + "/movies/search") else {
            throw NetworkError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = authManager.jwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let decoded = try JSONDecoder().decode(MovieSearchResponse.self, from: data)
        return decoded.results
    }

    // MARK: - Auth
    func register(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/register")!
        let body = ["email": email, "password": password]
        return try await post(url: url, body: body)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/login")!
        let body = ["email": email, "password": password]
        return try await post(url: url, body: body)
    }

    func requestPasswordReset(email: String) async throws {
        let url = URL(string: baseURL + "/auth/reset-password")!
        let body = ["email": email]
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    // MARK: - User Profile
    func createUserProfile(jwt: String, displayName: String, email: String, bio: String?, avatarUrl: String?) async throws -> UserProfile {
        let url = URL(string: baseURL + "/users")!
        let body = UserProfileRequest(display_name: displayName, email: email, bio: bio, avatar_url: avatarUrl)
        return try await post(url: url, body: body, jwt: jwt)
    }

    func getCurrentUserProfile(jwt: String) async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/me")!
        return try await get(url: url, jwt: jwt)
    }

    func updateCurrentUserProfile(jwt: String, displayName: String?, email: String?, bio: String?, avatarUrl: String?) async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/me")!
        let body = UserProfileRequest(display_name: displayName, email: email, bio: bio, avatar_url: avatarUrl)
        return try await patch(url: url, body: body, jwt: jwt)
    }

    // MARK: - Movies
    func getMovieDetails(movieId: String, jwt: String) async throws -> Movie {
        let url = URL(string: baseURL + "/movies/\(movieId)")!
        return try await get(url: url, jwt: jwt)
    }

    // MARK: - Reviews
    func getMyReviews(jwt: String) async throws -> [Review] {
        let url = URL(string: baseURL + "/users/me/reviews")!
        return try await get(url: url, jwt: jwt)
    }

    // MARK: - Generic Helpers
    private func get<T: Decodable>(url: URL, jwt: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let jwt = jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        return try await send(request: request)
    }

    private func post<T: Decodable, B: Encodable>(url: URL, body: B, jwt: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt = jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request: request)
    }

    private func patch<T: Decodable, B: Encodable>(url: URL, body: B, jwt: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt = jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request: request)
    }

    private func send<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        } else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw apiError
            } else {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
            }
        }
    }
}
