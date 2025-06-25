import Foundation

struct Movie: Codable, Identifiable, Hashable {
    let id: String // maps to movie_id
    let title: String
    let year: Int?
    let genres: [String]?
    let director: String?
    let cast: [String]?
    let description: String?
    let posterUrl: String?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case id = "movie_id"
        case title, year, genres, director, cast, description, posterUrl = "poster_url", rating
    }
} 