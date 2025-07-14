import Foundation

struct Collection: Codable, Identifiable, Hashable {
    let id: String // collection_id
    let userId: String // user_id
    let name: String
    let description: String?
    let visibility: String // "private" | "friends"
    let createdAt: String
    let updatedAt: String
    let reviewCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "collection_id"
        case userId = "user_id"
        case name
        case description
        case visibility
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case reviewCount = "review_count"
    }
}

struct CollectionResponse: Codable {
    let collections: [Collection]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case collections
        case totalCount = "total_count"
    }
}

struct CollectionsResponse: Codable {
    let collections: [CollectionWithReviews]
    let totalCollections: Int
    let totalReviews: Int
    
    enum CodingKeys: String, CodingKey {
        case collections
        case totalCollections = "total_collections"
        case totalReviews = "total_reviews"
    }
} 