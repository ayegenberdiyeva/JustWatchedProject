import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recommendations: [RecommendationResult] = []
    @Published var generatedAt: String? = nil
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let cacheManager = CacheManager.shared

    func fetchRecommendations(jwt: String) async {
        // First, try to load from cache
        if let cachedRecommendations = cacheManager.getCachedRecommendations() {
            // Convert cached movies to recommendation results
            self.recommendations = cachedRecommendations.map { movie in
                RecommendationResult(
                    movieId: String(movie.id),
                    title: movie.title,
                    posterPath: movie.posterPath,
                    confidenceScore: nil,
                    reasoning: nil,
                    mediaType: "movie"
                )
            }
        }
        
        isLoading = true
        error = nil
        guard let url = URL(string: "https://itsjustwatched.com/api/v1/users/me/recommendations") else { 
            error = "Invalid URL"
            isLoading = false
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    error = "No recommendations yet, please check back later."
                    recommendations = []
                    generatedAt = nil
                    isLoading = false
                    return
                }
            }
            
            // Try to decode
            let recs = try JSONDecoder().decode(UserRecommendationsResponse.self, from: data)
            recommendations = recs.recommendations
            generatedAt = recs.generatedAt
            
            // Cache the recommendations (convert to Movie objects for caching)
            let movies = recs.recommendations.map { rec in
                Movie(
                    id: Int(rec.movieId) ?? 0,
                    title: rec.title,
                    posterPath: rec.posterPath,
                    releaseDate: nil,
                    overview: nil
                )
            }
            cacheManager.cacheRecommendations(movies)
            
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            switch decodingError {
            case .dataCorrupted(let context):
                error = "Data corrupted: \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                error = "Missing key '\(key.stringValue)': \(context.debugDescription)"
            case .typeMismatch(let type, let context):
                error = "Type mismatch for \(type): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                error = "Value not found for \(type): \(context.debugDescription)"
            @unknown default:
                error = "Unknown decoding error: \(decodingError.localizedDescription)"
            }
        } catch {
            print("Network error: \(error)")
            self.error = "Network error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 