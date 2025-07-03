import Foundation

struct UserProfile: Codable, Hashable {
    let displayName: String?
    let email: String
    let bio: String?
    let color: String?
    let createdAt: String?
    let personalRecommendations: [String]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case bio
        case color
        case createdAt = "created_at"
        case personalRecommendations = "personal_recommendations"
    }
} 