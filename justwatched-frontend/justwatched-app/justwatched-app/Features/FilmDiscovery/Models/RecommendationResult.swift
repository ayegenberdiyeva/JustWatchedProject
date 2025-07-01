import Foundation

struct RecommendationResult: Codable, Identifiable, Hashable {
    let id: String // maps to movie_id
    let title: String
    let reason: String?
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case id = "movie_id"
        case title, reason, score
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