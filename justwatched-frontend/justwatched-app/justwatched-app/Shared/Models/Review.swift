import Foundation

struct Review: Identifiable, Codable, Hashable {
    let id: String?
    let mediaId: String
    let mediaType: String // "movie" or "tv"
    let userId: String? // user_id
    let rating: Int
    let content: String?
    let createdAt: Date?
    let updatedAt: Date?
    let title: String
    let posterPath: String?
    let watchedDate: Date?
    let status: String // "watched" | "watchlist"
    let collections: [String]? // collection IDs
    
    enum CodingKeys: String, CodingKey {
        case id = "review_id"
        case mediaId = "media_id"
        case mediaType = "media_type"
        case userId = "user_id"
        case rating
        case content = "review_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title = "media_title"
        case posterPath = "poster_path"
        case watchedDate = "watched_date"
        case status
        case collections
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        mediaId = try container.decode(String.self, forKey: .mediaId)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        let ratingDouble = try container.decode(Double.self, forKey: .rating)
        rating = Int(ratingDouble)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = Review.parseDate(from: createdAtString)
        } else {
            createdAt = nil
        }
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = Review.parseDate(from: updatedAtString)
        } else {
            updatedAt = nil
        }
        if let watchedDateString = try container.decodeIfPresent(String.self, forKey: .watchedDate) {
            watchedDate = Review.parseDate(from: watchedDateString)
        } else {
            watchedDate = nil
        }
        title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? "Media #\(mediaId)"
        status = try container.decode(String.self, forKey: .status)
        collections = try container.decodeIfPresent([String].self, forKey: .collections)
    }
    
    private static func parseDate(from dateString: String) -> Date? {
        // Try with fractional seconds first (for created_at and updated_at)
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractional.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds (for watched_date)
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]
        if let date = formatterWithoutFractional.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaId)
        hasher.combine(mediaType)
        hasher.combine(watchedDate)
    }
    
    static func == (lhs: Review, rhs: Review) -> Bool {
        return lhs.mediaId == rhs.mediaId && lhs.mediaType == rhs.mediaType && lhs.watchedDate == rhs.watchedDate
    }
}

struct ReviewRequest: Codable {
    let mediaId: String
    let mediaType: String  // "movie" or "tv"
    let rating: Double
    let content: String?
    let watchedDate: Date?
    let mediaTitle: String?
    let posterPath: String?
    let status: String // "watched" | "watchlist"
    let collections: [String]? // collection IDs
    
    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case mediaType = "media_type"
        case rating
        case content = "review_text"
        case watchedDate = "watched_date"
        case mediaTitle = "media_title"
        case posterPath = "poster_path"
        case status
        case collections
    }
} 