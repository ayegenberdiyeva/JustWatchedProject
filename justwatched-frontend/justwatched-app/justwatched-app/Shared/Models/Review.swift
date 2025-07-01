import Foundation

struct Review: Identifiable, Codable, Hashable {
    let id: String?
    let mediaId: String
    let mediaType: String // "movie" or "tv"
    let userId: String?
    let rating: Int
    let content: String?
    let createdAt: Date?
    let title: String
    let posterPath: String?
    let watchedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "review_id"
        case mediaId = "media_id"
        case mediaType = "media_type"
        case userId = "authorId"
        case rating
        case content = "review_text"
        case createdAt = "created_at"
        case title = "media_title"
        case posterPath = "poster_path"
        case watchedDate = "watched_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Optional fields
        id = try container.decodeIfPresent(String.self, forKey: .id)
        mediaId = try container.decode(String.self, forKey: .mediaId)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        
        // Handle rating as Double from backend, convert to Int
        let ratingDouble = try container.decode(Double.self, forKey: .rating)
        rating = Int(ratingDouble)
        
        // Optional fields with fallbacks
        content = try container.decodeIfPresent(String.self, forKey: .content)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        
        // Date fields with flexible parsing
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        if let watchedDateString = try container.decodeIfPresent(String.self, forKey: .watchedDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            watchedDate = formatter.date(from: watchedDateString)
        } else {
            watchedDate = nil
        }
        
        // Use title from backend, fallback to mediaId if missing
        title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? "Media #\(mediaId)"
    }
    
    // Custom Hashable implementation to ensure proper UI updates
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
    
    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case mediaType = "media_type"
        case rating
        case content = "review_text"
        case watchedDate = "watched_date"
        case mediaTitle = "media_title"
        case posterPath = "poster_path"
    }
} 