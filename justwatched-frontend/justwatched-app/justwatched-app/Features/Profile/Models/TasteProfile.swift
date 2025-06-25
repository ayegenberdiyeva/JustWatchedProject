import Foundation

struct TasteProfile: Codable, Identifiable, Hashable {
    let id: String // maps to user_id
    let favoriteGenres: [String]
    let favoriteActors: [String]?
    let favoriteDirectors: [String]?
    let moodPreferences: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case favoriteGenres = "favorite_genres"
        case favoriteActors = "favorite_actors"
        case favoriteDirectors = "favorite_directors"
        case moodPreferences = "mood_preferences"
    }
} 