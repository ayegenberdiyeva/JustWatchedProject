import Foundation

struct GroupRecommendationResult: Codable, Identifiable, Hashable {
    let id: String // maps to movie_id
    let groupId: String
    let title: String
    let groupScore: Double
    let reasons: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "movie_id"
        case groupId = "group_id"
        case title
        case groupScore = "group_score"
        case reasons
    }
}

struct GroupRecommendationList: Codable {
    let groupId: String
    let recommendations: [GroupRecommendationResult]

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case recommendations
    }
} 