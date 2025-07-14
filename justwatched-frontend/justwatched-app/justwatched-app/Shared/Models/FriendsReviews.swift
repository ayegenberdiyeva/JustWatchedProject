import Foundation

// MARK: - Data Models for Friends Reviews
struct FriendsReviewsResponse: Codable {
    let friends: [FriendReviewsData]
    let totalFriends: Int
    let totalCollections: Int
    let totalReviews: Int
    
    enum CodingKeys: String, CodingKey {
        case friends
        case totalFriends = "total_friends"
        case totalCollections = "total_collections"
        case totalReviews = "total_reviews"
    }
}

struct FriendReviewsData: Codable, Identifiable {
    let userId: String
    let displayName: String
    let color: String
    let collections: [CollectionWithReviews]
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case color
        case collections
    }
}

struct CollectionWithReviews: Codable, Identifiable {
    let collectionId: String
    let name: String
    let description: String?
    let visibility: String
    let reviewCount: Int
    let reviews: [Review]
    
    var id: String { collectionId }
    
    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case name
        case description
        case visibility
        case reviewCount = "review_count"
        case reviews
    }
} 