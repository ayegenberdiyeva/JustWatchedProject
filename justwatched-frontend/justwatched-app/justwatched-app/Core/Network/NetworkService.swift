import Foundation

extension URLRequest {
    init(url: URL, method: String, body: Data?) {
        self.init(url: url)
        self.httpMethod = method
        self.httpBody = body
        self.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}

struct EmptyResponse: Codable {}

struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user_id: String
    let expires_in: Int
}

struct APIError: Codable, LocalizedError {
    let detail: String
    var errorDescription: String? { detail }
}

struct UserProfileRequest: Encodable {
    let display_name: String
    let email: String
    let bio: String?
    let color: String?
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
    // private let baseURL = "http://localhost:8000/api/v1"
    // private let baseURL = "http://132.220.224.42:8000/api/v1"
    private let baseURL = "https://itsjustwatched.com/api/v1"
    private let authManager = AuthManager.shared
    
    private init() {}
    
    private func authorizedRequest(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        // Get a valid access token (refresh if needed)
        let accessToken = try await authManager.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for token refresh headers
        if let httpResponse = response as? HTTPURLResponse {
            let newAccessToken = httpResponse.value(forHTTPHeaderField: "x-new-access-token")
            let newRefreshToken = httpResponse.value(forHTTPHeaderField: "x-new-refresh-token")
            
            if let newAccess = newAccessToken, let newRefresh = newRefreshToken {
                // Update tokens with new ones from response headers
                let authResponse = AuthResponse(
                    access_token: newAccess,
                    refresh_token: newRefresh,
                    user_id: "",
                    expires_in: 3600
                )
                await authManager.setTokens(from: authResponse)
            }
        }
        
        return (data, response)
    }
    
    // MARK: - Authentication Error Handling
    private func handleAuthenticationError(_ response: URLResponse) async {
        await AuthErrorHandler.shared.handleAuthenticationError(response)
    }
    
    func fetchProfile() async throws -> UserProfile {
        let (data, response) = try await authorizedRequest("/users/me")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    func updateProfile(displayName: String?, email: String?, bio: String?, color: String?) async throws {
        let parameters: [String: Any?] = [
            "display_name": displayName,
            "email": email,
            "bio": bio,
            "color": color
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: parameters.compactMapValues { $0 })
        let (_, response) = try await authorizedRequest("/users/me", method: "PATCH", body: jsonData)
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func fetchUserReviews() async throws -> [Review] {
        let (data, response) = try await authorizedRequest("/reviews/users/me/reviews")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let reviews = try decoder.decode([Review].self, from: data)
            return reviews
        } catch {
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    break
                case .typeMismatch(let type, let context):
                    break
                case .valueNotFound(let type, let context):
                    break
                case .dataCorrupted(let context):
                    break
                @unknown default:
                    break
                }
            }
            throw NetworkError.decodingFailed(error)
        }
    }
    
    func postReview(review: ReviewRequest) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(review)
        
        let (_, response) = try await authorizedRequest("/reviews/", method: "POST", body: jsonData)
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func deleteReview(reviewId: String) async throws {
        let (_, response) = try await authorizedRequest("/reviews/\(reviewId)", method: "DELETE")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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

    // MARK: - Auth
    func register(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/register")!
        let body = ["email": email, "password": password]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, method: "POST", body: jsonData))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(AuthResponse.self, from: data)
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

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/login")!
        let body = ["email": email, "password": password]
        
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, method: "POST", body: jsonData))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(AuthResponse.self, from: data)
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
    
    func refreshTokens(refreshToken: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/refresh")!
        let body = ["refresh_token": refreshToken]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, method: "POST", body: jsonData))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(AuthResponse.self, from: data)
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

    func requestPasswordReset(email: String) async throws {
        let url = URL(string: baseURL + "/auth/request-password-reset")!
        let body = ["email": email]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, method: "POST", body: jsonData))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if !(200..<300).contains(httpResponse.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw apiError
            } else {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
            }
        }
    }

    // MARK: - User Profile
    func createUserProfile(userId: String, displayName: String, email: String, bio: String?, color: String? = "red") async throws -> UserProfile {
        // Include user_id in the request to link to the auth record
        let body: [String: Any] = [
            "user_id": userId,
            "display_name": displayName,
            "email": email,
            "bio": bio ?? "No bio yet",
            "color": color ?? "red"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await authorizedRequest("/users", method: "POST", body: jsonData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        

        
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(UserProfile.self, from: data)
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
    
    func updateUserProfile(displayName: String, email: String, bio: String?, color: String? = "red") async throws -> UserProfile {
        let body = UserProfileRequest(display_name: displayName, email: email, bio: bio, color: color)
        return try await patch(endpoint: "/users/me", body: body)
    }

    func getCurrentUserProfile() async throws -> UserProfile {
        let (data, response) = try await authorizedRequest("/users/me")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        return profile
    }

    func updateCurrentUserProfile(displayName: String?, email: String?, bio: String?) async throws -> UserProfile {
        let body = UserProfileRequest(display_name: displayName ?? "", email: email ?? "", bio: bio, color: nil)
        return try await patch(endpoint: "/users/me", body: body)
    }

    // MARK: - Movies
    func getMovieDetails(movieId: String) async throws -> Movie {
        let (data, response) = try await authorizedRequest("/movies/\(movieId)")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode(Movie.self, from: data)
    }

    // MARK: - Reviews
    func getMyReviews() async throws -> [Review] {
        let (data, response) = try await authorizedRequest("/reviews/users/me/reviews")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Review].self, from: data)
    }

    // MARK: - Search History
    func fetchSearchHistory(limit: Int = 5, offset: Int = 0) async throws -> ([SearchHistoryEntry], Bool) {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        var urlComponents = URLComponents(string: baseURL + "/search-history")!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            var dateStr = try container.decode(String.self)
            // Truncate microseconds to milliseconds if needed
            if let dotRange = dateStr.range(of: ".") {
                let start = dotRange.upperBound
                let afterDot = dateStr[start...]
                let digits = afterDot.prefix(while: { $0.isNumber })
                if digits.count > 3 {
                    let ms = digits.prefix(3)
                    let rest = afterDot.dropFirst(digits.count)
                    dateStr = String(dateStr[..<start]) + ms + rest
                }
            }
            // Add 'Z' if missing
            if !dateStr.hasSuffix("Z") {
                dateStr += "Z"
            }
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateStr)")
        }
        do {
            let result = try decoder.decode(SearchHistoryResponse.self, from: data)
            return (result.searches, result.hasMore)
        } catch {
            throw error
        }
    }

    func deleteSearchHistoryEntry(id: String) async throws {
        let (_, response) = try await authorizedRequest("/search_history/\(id)", method: "DELETE")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    func clearSearchHistory() async throws {
        let (_, response) = try await authorizedRequest("/search_history", method: "DELETE")
        
        // Handle authentication errors
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    // MARK: - Collections
    func fetchUserCollections(includePrivate: Bool = true) async throws -> [Collection] {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        var urlComponents = URLComponents(string: baseURL + "/collections/")!
        urlComponents.queryItems = [
            URLQueryItem(name: "include_private", value: includePrivate ? "true" : "false")
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let decoded = try JSONDecoder().decode(CollectionResponse.self, from: data)
        return decoded.collections
    }
    
    func fetchUserCollectionsWithReviews(includePrivate: Bool = true) async throws -> CollectionsResponse {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        var urlComponents = URLComponents(string: baseURL + "/collections/me/reviews")!
        urlComponents.queryItems = [
            URLQueryItem(name: "include_private", value: includePrivate ? "true" : "false")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(CollectionsResponse.self, from: data)
    }

    func createCollection(name: String, description: String?, visibility: String) async throws -> Collection {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any?] = [
            "name": name,
            "description": description,
            "visibility": visibility
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(Collection.self, from: data)
    }
    
    func updateCollection(collectionId: String, name: String?, description: String?, visibility: String?) async throws -> Collection {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/\(collectionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any?] = [
            "name": name,
            "description": description,
            "visibility": visibility
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(Collection.self, from: data)
    }
    
    func deleteCollection(collectionId: String) async throws {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/\(collectionId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {

            throw NetworkError.invalidResponse
        }
        

        
        if httpResponse.statusCode == 200 {

        } else {

            if let errorString = String(data: data, encoding: .utf8) {

            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    func addReviewToCollection(collectionId: String, reviewId: String) async throws {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/\(collectionId)/reviews/\(reviewId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func removeReviewFromCollection(collectionId: String, reviewId: String) async throws {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/\(collectionId)/reviews/\(reviewId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func getCollectionReviews(collectionId: String) async throws -> CollectionReviewsResponse {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/collections/\(collectionId)/reviews")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CollectionReviewsResponse.self, from: data)
    }

    // MARK: - User Color
    struct UserColor: Codable, Hashable {
        let value: String
        let name: String
    }
    struct UserColorsResponse: Codable {
        let colors: [UserColor]
        let `default`: String
    }
    func fetchAvailableUserColors() async throws -> UserColorsResponse {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/users/colors")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(UserColorsResponse.self, from: data)
    }
    func updateUserColor(color: String) async throws {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/users/me/color")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = ["color": color]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
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

    private func post<T: Decodable, B: Encodable>(url: URL, body: B) async throws -> T {
        let jsonData = try JSONEncoder().encode(body)
        let (data, response) = try await authorizedRequest(url.path, method: "POST", body: jsonData)
        
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

    private func patch<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        let jsonData = try JSONEncoder().encode(body)
        let (data, response) = try await authorizedRequest(endpoint, method: "PATCH", body: jsonData)
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

    func searchMoviesOrTV(query: String, searchType: String) async throws -> [SearchResult] {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        urlComponents.path = "/movies/search"
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "search_type", value: searchType)
        ]
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        // Build the endpoint as a relative path for authorizedRequest
        var endpoint = urlComponents.path
        if let query = urlComponents.percentEncodedQuery, !query.isEmpty {
            endpoint += "?" + query
        }
        let (data, response) = try await authorizedRequest(endpoint)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        if searchType == "movie" {
            let decoded = try JSONDecoder().decode(MovieSearchResponse.self, from: data)
            return decoded.results.map { .movie($0) }
        } else if searchType == "tv" {
            let decoded = try JSONDecoder().decode(TVShowSearchResponse.self, from: data)
            return decoded.results.map { .tvShow($0) }
        } else {
            return []
        }
    }

    func getOtherUserProfile(userId: String) async throws -> UserProfile {
        
        let (data, response) = try await authorizedRequest("/users/\(userId)")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {

            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func searchUsers(displayName: String) async throws -> [UserSearchResult] {
        let (data, response) = try await authorizedRequest("/users/search?display_name=\(displayName)")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // Decode the response wrapper
        struct UserSearchResponse: Codable {
            let users: [UserSearchResult]
        }
        
        let searchResponse = try JSONDecoder().decode(UserSearchResponse.self, from: data)
        return searchResponse.users
    }
    
    func fetchFriendsReviews() async throws -> FriendsReviewsResponse {
        let (data, response) = try await authorizedRequest("/friends/reviews")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FriendsReviewsResponse.self, from: data)
    }

    func createUserProfileWithId(userId: String, displayName: String, email: String, bio: String?, color: String? = "red") async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/\(userId)")!
        let body = UserProfileRequest(display_name: displayName, email: email, bio: bio, color: color)
        

        
        return try await post(url: url, body: body) // No JWT needed for initial creation
    }
    
    // MARK: - Account Deletion
    func deleteAccount() async throws -> AccountDeletionResponse {
        let (data, response) = try await authorizedRequest("/users/me", method: "DELETE")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {

            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode(AccountDeletionResponse.self, from: data)
    }
}

// MARK: - Account Deletion Models
struct AccountDeletionResponse: Codable {
    let message: String
    let deletion_summary: DeletionSummary
}

struct DeletionSummary: Codable {
    let user_id: String
    let deleted_items: DeletedItems
    let errors: [String]
    let success: Bool
}

struct DeletedItems: Codable {
    let reviews: Int
    let collections: Int
    let watchlist_items: Int
    let taste_profile: Int
    let recommendations: Int
    let search_history: Int
    let moodboards: Int
    let rooms_handled: Int
    let room_invitations: Int
    let friendships_removed: Int
    let friend_requests: Int
    let cache_cleared: Int
    let user_profile: Int
}
 
