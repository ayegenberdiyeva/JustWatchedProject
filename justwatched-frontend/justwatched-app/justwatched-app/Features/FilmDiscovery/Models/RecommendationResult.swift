import Foundation

struct RecommendationResult: Codable, Identifiable, Hashable {
    let movieId: String // maps to movie_id
    let title: String
    let posterPath: String?
    let confidenceScore: Double?
    let reasoning: String?
    let mediaType: String // "movie" or "tv"
    
    // Create a unique ID by combining movie_id and title
    var id: String { "\(movieId)_\(title)" }
    
    // Custom initializer for creating from Movie objects
    init(movieId: String, title: String, posterPath: String?, confidenceScore: Double? = nil, reasoning: String? = nil, mediaType: String = "movie") {
        self.movieId = movieId
        self.title = title
        self.posterPath = posterPath
        self.confidenceScore = confidenceScore
        self.reasoning = reasoning
        self.mediaType = mediaType
    }

    enum CodingKeys: String, CodingKey {
        case movieId = "movie_id"
        case title
        case posterPath = "poster_path"
        case confidenceScore = "confidence_score"
        case reasoning
        case mediaType = "media_type"
    }
    
    // Try multiple possible field names for movie ID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode movieId with different possible field names
        if let movieId = try? container.decode(String.self, forKey: .movieId) {
            self.movieId = movieId
        } else {
            // Try alternative field names
            let altContainer = try decoder.container(keyedBy: AlternativeCodingKeys.self)
            if let tmdbId = try? altContainer.decode(String.self, forKey: .tmdbId) {
                self.movieId = tmdbId
            } else if let id = try? altContainer.decode(String.self, forKey: .id) {
                self.movieId = id
            } else {
                throw DecodingError.keyNotFound(CodingKeys.movieId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not find movie_id, tmdb_id, or id field"))
            }
        }
        
        title = try container.decode(String.self, forKey: .title)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        // Default to "movie" if media_type is not present in the response
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType) ?? "movie"
    }
    
    private enum AlternativeCodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case id
    }
}

struct PersonalRecommendationList: Codable {
    let userId: String
    let recommendations: [RecommendationResult]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recommendations
    }
}

struct UserRecommendationsResponse: Codable {
    let recommendations: [RecommendationResult]
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case recommendations
        case generatedAt = "generated_at"
    }
} 