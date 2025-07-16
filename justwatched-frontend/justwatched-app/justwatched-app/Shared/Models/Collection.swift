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
    let autoSelect: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "collection_id"
        case userId = "user_id"
        case name
        case description
        case visibility
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case reviewCount = "review_count"
        case autoSelect = "auto_select"
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

// MARK: - Collections with Reviews (for /collections/me/reviews endpoint)
struct CollectionsResponse: Codable {
    let collections: [UserCollectionWithReviews]
    let totalCollections: Int
    let totalReviews: Int
    
    enum CodingKeys: String, CodingKey {
        case collections
        case totalCollections = "total_collections"
        case totalReviews = "total_reviews"
    }
}

struct UserCollectionWithReviews: Codable, Identifiable {
    let collectionId: String
    let name: String
    let description: String?
    let visibility: String
    let reviewCount: Int
    let reviews: [UserCollectionReview]
    
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

// MARK: - Collection Reviews Models
struct CollectionReviewsResponse: Codable {
    let collectionId: String
    let collectionName: String
    let reviews: [UserCollectionReview]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case collectionName = "collection_name"
        case reviews
        case totalCount = "total_count"
    }
}

struct UserCollectionReview: Codable, Identifiable, Hashable {
    let reviewId: String
    let mediaId: String
    let mediaTitle: String
    let mediaType: String
    let posterPath: String?
    let rating: Int?
    let reviewText: String?
    let watchedDate: String?
    let status: String
    let createdAt: String
    let updatedAt: String
    
    var id: String { reviewId }
    
    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case mediaId = "media_id"
        case mediaTitle = "media_title"
        case mediaType = "media_type"
        case posterPath = "poster_path"
        case rating
        case reviewText = "review_text"
        case watchedDate = "watched_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 