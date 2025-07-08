import Foundation

// Make sure Recommendation and RecommendationResponse are available in scope
// If not, import from the appropriate module or copy their definitions here

actor RecommendationService {
    static let shared = RecommendationService()
    private let baseURL = "http://localhost:8000"
    private let session = URLSession.shared

    func fetchPersonalRecommendations(tasteProfile: [String: Any], watchedMovieIDs: [Int]) async throws -> [Recommendation] {
        guard let url = URL(string: baseURL + "/recommend/personal") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "taste_profile": tasteProfile,
            "watched_movie_ids": watchedMovieIDs
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
        return decoded.recommendations
    }
} 