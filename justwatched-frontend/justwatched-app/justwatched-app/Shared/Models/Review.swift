import Foundation

struct Review: Identifiable, Codable, Hashable {
    let id: String
    let movieId: String
    let userId: String
    let rating: Int
    let content: String?
    let createdAt: Date
    let movieTitle: String
    let posterPath: String?
    let watchedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "review_id"
        case movieId = "movie_id"
        case userId = "authorId"
        case rating
        case content = "review_text"
        case createdAt = "created_at"
        case movieTitle = "movie_title"
        case posterPath = "poster_path"
        case watchedDate = "watched_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        movieId = try container.decode(String.self, forKey: .movieId)
        userId = try container.decode(String.self, forKey: .userId)
        
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
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        if let watchedDateString = try container.decodeIfPresent(String.self, forKey: .watchedDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            watchedDate = formatter.date(from: watchedDateString)
        } else {
            watchedDate = nil
        }
        
        // Use movieTitle from backend, fallback to movieId if missing
        movieTitle = (try container.decodeIfPresent(String.self, forKey: .movieTitle)) ?? "Movie #\(movieId)"
    }
    
    // Custom Hashable implementation to ensure proper UI updates
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Review, rhs: Review) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ReviewRequest: Codable {
    let movieId: String
    let rating: Int
    let content: String?
    let watchedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case movieId = "movie_id"
        case rating
        case content = "review_text"
        case watchedDate = "watched_date"
    }
} 