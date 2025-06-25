import Foundation

struct MusicTrack: Codable, Identifiable, Hashable {
    let id: String // maps to track_id
    let title: String
    let artist: String
    let album: String?
    let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "track_id"
        case title, artist, album
        case previewUrl = "preview_url"
    }
}

struct MoodboardAssets: Codable, Identifiable, Hashable {
    let id: String // maps to user_id
    let images: [String]
    let musicTracks: [MusicTrack]

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case images
        case musicTracks = "music_tracks"
    }
} 