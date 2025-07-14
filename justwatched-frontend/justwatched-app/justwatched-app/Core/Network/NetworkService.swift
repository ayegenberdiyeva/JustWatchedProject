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
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 || httpResponse.statusCode == 403 {
                await MainActor.run {
                    AuthManager.shared.signOut()
                    AppState.shared.isAuthenticated = false
                }
            }
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
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    func fetchUserReviews() async throws -> [Review] {
        let (data, response) = try await authorizedRequest("/reviews/users/me/reviews")
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
        
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                await MainActor.run {
                    AuthManager.shared.signOut()
                    AppState.shared.isAuthenticated = false
                }
            }
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
        
        // Debug: Print registration request
        print("🔍 Registration request body:")
        print(body)
        
        let response: AuthResponse = try await post(url: url, body: body)
        
        // Debug: Print registration response
        print("✅ Registration response:")
        print("Access token: \(response.access_token)")
        print("User ID: \(response.user_id)")
        
        return response
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: baseURL + "/auth/login")!
        let body = ["email": email, "password": password]
        return try await post(url: url, body: body)
    }

    func requestPasswordReset(email: String) async throws {
        let url = URL(string: baseURL + "/auth/request-password-reset")!
        let body = ["email": email]
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    // MARK: - User Profile
    func createUserProfile(jwt: String, userId: String, displayName: String, email: String, bio: String?, color: String? = "red") async throws -> UserProfile {
        let url = URL(string: baseURL + "/users")!
        
        // Include user_id in the request to link to the auth record
        let body: [String: Any] = [
            "user_id": userId,
            "display_name": displayName,
            "email": email,
            "bio": bio ?? "No bio yet",
            "color": color ?? "red"
        ]
        
        // Debug: Print the request body
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔍 Creating user profile with body:")
            print(jsonString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Debug: Print response
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 Backend response (\(httpResponse.statusCode)):")
            print(responseString)
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
    
    func updateUserProfile(jwt: String, displayName: String, email: String, bio: String?, color: String? = "red") async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/me")!
        let body = UserProfileRequest(display_name: displayName, email: email, bio: bio, color: color)
        
        // Debug: Print the request body
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(body),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔍 Updating user profile with body:")
            print(jsonString)
        }
        
        return try await patch(url: url, body: body, jwt: jwt)
    }

    func getCurrentUserProfile(jwt: String) async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 || httpResponse.statusCode == 403 {
                await MainActor.run {
                    AuthManager.shared.signOut()
                    AppState.shared.isAuthenticated = false
                }
            }
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        return profile
    }

    func updateCurrentUserProfile(jwt: String, displayName: String?, email: String?, bio: String?) async throws -> UserProfile {
        let url = URL(string: baseURL + "/users/me")!
        let body = UserProfileRequest(display_name: displayName ?? "", email: email ?? "", bio: bio, color: nil)
        return try await patch(url: url, body: body, jwt: jwt)
    }

    // MARK: - Movies
    func getMovieDetails(movieId: String, jwt: String) async throws -> Movie {
        let url = URL(string: baseURL + "/movies/\(movieId)")!
        return try await get(url: url, jwt: jwt)
    }

    // MARK: - Reviews
    func getMyReviews(jwt: String) async throws -> [Review] {
        let url = URL(string: baseURL + "/reviews/users/me/reviews")!
        return try await get(url: url, jwt: jwt)
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
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    func clearSearchHistory() async throws {
        let (_, response) = try await authorizedRequest("/search_history", method: "DELETE")
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
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
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
        print("🗑️ DELETE request URL: \(url)")
        print("🗑️ Collection ID: \(collectionId)")
        print("🗑️ JWT Token: \(token.prefix(20))...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🗑️ Sending DELETE request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw NetworkError.invalidResponse
        }
        
        print("🗑️ Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            print("✅ Collection deleted successfully")
        } else {
            print("❌ Delete failed with status code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorString)")
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
            // Debug: Print error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Backend error response (\(httpResponse.statusCode)):")
                print(errorString)
            }
            
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw apiError
            } else {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
            }
        }
    }

    func searchMoviesOrTV(query: String, searchType: String) async throws -> [SearchResult] {
        guard var urlComponents = URLComponents(string: baseURL + "/movies/search") else {
            throw NetworkError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "search_type", value: searchType)
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
        let url = URL(string: baseURL + "/users/\(userId)")!
        print("🔍 Getting other user profile for ID: \(userId)")
        print("🔍 URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let jwt = authManager.jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Debug: Print error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Backend error response (\((response as? HTTPURLResponse)?.statusCode ?? 0)):")
                print(errorString)
            }
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func searchUsers(displayName: String) async throws -> [UserSearchResult] {
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        var urlComponents = URLComponents(string: baseURL + "/users/search")!
        urlComponents.queryItems = [URLQueryItem(name: "display_name", value: displayName)]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("User search response:", String(data: data, encoding: .utf8) ?? "No data")
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
        guard let token = authManager.jwt else { throw NetworkError.invalidURL }
        let url = URL(string: baseURL + "/friends/reviews")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
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
        
        // Debug: Print the request body
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(body),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔍 Creating user profile with ID \(userId) and body:")
            print(jsonString)
        }
        
        return try await post(url: url, body: body, jwt: nil) // No JWT needed for initial creation
    }
}
 
