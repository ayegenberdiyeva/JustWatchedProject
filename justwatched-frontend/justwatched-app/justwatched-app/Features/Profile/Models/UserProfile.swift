import Foundation

struct UserProfile: Codable, Hashable, Identifiable {
    let userId: String
    let displayName: String?
    let email: String?
    let bio: String?
    let color: String?
    let createdAt: String?
    let personalRecommendations: [String]?
    let isFriend: Bool?
    
    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case email
        case bio
        case color
        case createdAt = "created_at"
        case personalRecommendations = "personal_recommendations"
        case isFriend = "is_friend"
    }
} 