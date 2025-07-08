import Foundation

struct UserSearchResult: Codable, Identifiable {
    let user_id: String
    let display_name: String
    let color: String?
    let is_friend: Bool
    let friend_status: String?
    var id: String { user_id }
} 