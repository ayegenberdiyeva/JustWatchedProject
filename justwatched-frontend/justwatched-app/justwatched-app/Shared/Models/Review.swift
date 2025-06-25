import Foundation

struct Review: Identifiable, Codable {
    let id: String
    let movieId: String
    let userId: String
    let rating: Int
    let content: String?
    let createdAt: Date
    let movieTitle: String
    let watchedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case movieId = "movie_id"
        case userId = "user_id"
        case rating
        case content = "review_text"
        case createdAt = "created_at"
        case movieTitle = "movie_title"
        case watchedDate = "watched_date"
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