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

    enum CodingKeys: String, CodingKey {
        case movieId = "movie_id"
        case title
        case posterPath = "poster_path"
        case confidenceScore = "confidence_score"
        case reasoning
        case mediaType = "media_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        movieId = try container.decode(String.self, forKey: .movieId)
        title = try container.decode(String.self, forKey: .title)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        // Default to "movie" if media_type is not present in the response
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType) ?? "movie"
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