import Foundation

struct Movie: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let overview: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
    }
}

struct TVShow: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let firstAirDate: String?
    let overview: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
    }
}

struct MovieSearchResponse: Codable {
    let results: [Movie]
}

struct TVShowSearchResponse: Codable {
    let results: [TVShow]
} 