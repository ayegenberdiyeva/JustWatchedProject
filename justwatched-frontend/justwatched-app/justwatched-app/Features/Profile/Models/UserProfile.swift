import Foundation

struct UserProfile: Codable, Hashable {
    let displayName: String?
    let email: String
    let bio: String?
    let avatarUrl: String?
    let createdAt: String?
    let personalRecommendations: [String]?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case bio
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case personalRecommendations = "personal_recommendations"
        case color
    }
} 