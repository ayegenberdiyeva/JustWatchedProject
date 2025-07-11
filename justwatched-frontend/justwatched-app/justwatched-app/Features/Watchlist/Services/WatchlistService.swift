import Foundation

actor WatchlistService {
    static let shared = WatchlistService()
    private let baseURL = "https://itsjustwatched.com/api/v1/watchlist/"
    private let session = URLSession.shared
    
    private init() {}
    
    func getWatchlist(jwt: String) async throws -> WatchlistResponse {
        guard let url = URL(string: baseURL) else {
            throw WatchlistServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchlistServiceError.requestFailed(statusCode: 500)
        }
        
        if httpResponse.statusCode == 404 {
            // Return empty watchlist if none exists
            return WatchlistResponse(items: [], totalCount: 0)
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            print("❌ Authentication error: \(httpResponse.statusCode)")
            // Handle authentication errors by signing out
            await MainActor.run {
                AuthManager.shared.signOut()
                AppState.shared.isAuthenticated = false
            }
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Watchlist request failed: \(httpResponse.statusCode)")
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(WatchlistResponse.self, from: data)
    }
    
    func addToWatchlist(jwt: String, mediaId: String, mediaType: String, mediaTitle: String, posterPath: String?) async throws -> WatchlistItem {
        guard let url = URL(string: baseURL) else {
            throw WatchlistServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AddToWatchlistRequest(
            mediaId: mediaId,
            mediaType: mediaType,
            mediaTitle: mediaTitle,
            posterPath: posterPath
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchlistServiceError.requestFailed(statusCode: 500)
        }
        
        if httpResponse.statusCode == 400 {
            throw WatchlistError.itemAlreadyInWatchlist
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            // Handle authentication errors by signing out
            await MainActor.run {
                AuthManager.shared.signOut()
                AppState.shared.isAuthenticated = false
            }
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(WatchlistItem.self, from: data)
    }
    
    func removeFromWatchlist(jwt: String, mediaId: String) async throws {
        guard let url = URL(string: "\(baseURL)\(mediaId)") else {
            throw WatchlistServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchlistServiceError.requestFailed(statusCode: 500)
        }
        
        if httpResponse.statusCode == 404 {
            throw WatchlistError.itemNotInWatchlist
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            // Handle authentication errors by signing out
            await MainActor.run {
                AuthManager.shared.signOut()
                AppState.shared.isAuthenticated = false
            }
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    func checkWatchlistStatus(jwt: String, mediaId: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)check/\(mediaId)") else {
            throw WatchlistServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchlistServiceError.requestFailed(statusCode: 500)
        }
        
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            // Handle authentication errors by signing out
            await MainActor.run {
                AuthManager.shared.signOut()
                AppState.shared.isAuthenticated = false
            }
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WatchlistServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        let checkResponse = try JSONDecoder().decode(WatchlistCheckResponse.self, from: data)
        return checkResponse.isInWatchlist
    }
}

enum WatchlistServiceError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .requestFailed(let code):
            return "The network request failed with status code \(code)."
        case .decodingFailed:
            return "Failed to decode the server response."
        }
    }
}

enum WatchlistError: LocalizedError {
    case itemAlreadyInWatchlist
    case itemNotInWatchlist
    
    var errorDescription: String? {
        switch self {
        case .itemAlreadyInWatchlist:
            return "This item is already in your watchlist."
        case .itemNotInWatchlist:
            return "This item is not in your watchlist."
        }
    }
}

 