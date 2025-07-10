import Foundation

struct RecommendationResult: Codable, Identifiable, Hashable {
    let id: String // maps to movie_id
    let title: String
    let posterPath: String?
    let confidenceScore: Double?
    let reasoning: String?
    let mediaType: String // "movie" or "tv"

    enum CodingKeys: String, CodingKey {
        case id = "movie_id"
        case title
        case posterPath = "poster_path"
        case confidenceScore = "confidence_score"
        case reasoning
        case mediaType = "media_type"
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