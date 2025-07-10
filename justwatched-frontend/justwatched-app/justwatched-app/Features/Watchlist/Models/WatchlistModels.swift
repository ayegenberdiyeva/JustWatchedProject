import Foundation

struct WatchlistItem: Codable, Identifiable, Hashable {
    let userId: String
    let mediaId: String
    let mediaType: String
    let mediaTitle: String
    let posterPath: String?
    let addedAt: String
    
    // Computed property for Identifiable conformance
    var id: String { mediaId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case mediaId = "media_id"
        case mediaType = "media_type"
        case mediaTitle = "media_title"
        case posterPath = "poster_path"
        case addedAt = "added_at"
    }
}

struct WatchlistResponse: Codable {
    let items: [WatchlistItem]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

struct WatchlistCheckResponse: Codable {
    let mediaId: String
    let isInWatchlist: Bool
    
    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case isInWatchlist = "is_in_watchlist"
    }
}

struct AddToWatchlistRequest: Codable {
    let mediaId: String
    let mediaType: String
    let mediaTitle: String
    let posterPath: String?
    
    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case mediaType = "media_type"
        case mediaTitle = "media_title"
        case posterPath = "poster_path"
    }
} 