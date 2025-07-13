import Foundation

// MARK: - Core Room Models
struct Room: Codable, Identifiable {
    let roomId: String
    let name: String
    let description: String?
    let status: RoomStatus
    let maxParticipants: Int
    let currentParticipants: Int
    let createdAt: String
    let updatedAt: String
    let ownerId: String
    let participants: [RoomParticipant]
    let currentRecommendations: [RoomRecommendation]?
    
    var id: String { roomId }
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case description
        case status
        case maxParticipants = "max_participants"
        case currentParticipants = "current_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ownerId = "owner_id"
        case participants
        case currentRecommendations = "current_recommendations"
    }
    
    // Custom initializer to handle potential missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        roomId = try container.decode(String.self, forKey: .roomId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(RoomStatus.self, forKey: .status)
        maxParticipants = try container.decode(Int.self, forKey: .maxParticipants)
        currentParticipants = try container.decode(Int.self, forKey: .currentParticipants)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        participants = try container.decode([RoomParticipant].self, forKey: .participants)
        currentRecommendations = try container.decodeIfPresent([RoomRecommendation].self, forKey: .currentRecommendations)
    }
}

enum RoomStatus: String, Codable, CaseIterable {
    case active = "active"
    case processing = "processing"
    case completed = "completed"
    case inactive = "inactive"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .inactive: return "Inactive"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .processing: return "yellow"
        case .completed: return "blue"
        case .inactive: return "gray"
        }
    }
}

struct RoomParticipant: Codable, Identifiable {
    let userId: String
    let displayName: String?
    let joinedAt: String
    let isOwner: Bool
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case joinedAt = "joined_at"
        case isOwner = "is_owner"
    }
}

struct RoomRecommendation: Codable, Identifiable {
    let movieId: String
    let title: String
    let posterPath: String?
    let groupScore: Double
    let reasons: [String]
    let participantsWhoLiked: [String]
    
    var id: String { movieId }
    
    enum CodingKeys: String, CodingKey {
        case movieId = "movie_id"
        case title
        case posterPath = "poster_path"
        case groupScore = "group_score"
        case reasons
        case participantsWhoLiked = "participants_who_liked"
    }
}

// MARK: - Request/Response Models
struct RoomCreateRequest: Codable {
    let name: String
    let description: String?
    let maxParticipants: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case maxParticipants = "max_participants"
    }
}

struct RoomUpdateRequest: Codable {
    let name: String?
    let description: String?
    let maxParticipants: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case maxParticipants = "max_participants"
    }
}

struct RoomProcessResponse: Codable {
    let status: String
    let message: String
    let participantCount: Int
    let recommendationCount: Int
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case participantCount = "participant_count"
        case recommendationCount = "recommendation_count"
    }
}

struct RoomRecommendationsResponse: Codable {
    let roomId: String
    let recommendations: [RoomRecommendation]
    let generatedAt: String
    let participantCount: Int
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case recommendations
        case generatedAt = "generated_at"
        case participantCount = "participant_count"
    }
}

// MARK: - API Response Wrappers
struct RoomsResponse: Codable {
    let rooms: [Room]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case rooms
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

struct RoomResponse: Codable {
    let room: Room
}

// MARK: - WebSocket Models
enum WebSocketMessageType: String, Codable {
    case vote = "vote"
    case startVoting = "start_voting"
    case getRoomStatus = "get_room_status"
    case ping = "ping"
    case roomState = "room_state"
    case currentMovie = "current_movie"
    case voteConfirmed = "vote_confirmed"
    case votingResult = "voting_result"
    case error = "error"
}

struct WebSocketVoteMessage: Codable {
    let type: String = "vote"
    let movieId: String
    let vote: String // "like" or "dislike"
    
    enum CodingKeys: String, CodingKey {
        case type
        case movieId = "movie_id"
        case vote
    }
}

struct WebSocketStartVotingMessage: Codable {
    let type: String = "start_voting"
}

struct WebSocketGetRoomStatusMessage: Codable {
    let type: String = "get_room_status"
}

struct WebSocketPingMessage: Codable {
    let type: String = "ping"
    let timestamp: Int
}

struct WebSocketRoomStateMessage: Codable {
    let type: String
    let roomId: String
    let participants: [RoomParticipant]
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case roomId = "room_id"
        case participants
        case status
    }
}

struct WebSocketCurrentMovieMessage: Codable {
    let type: String
    let roomId: String
    let movie: RoomRecommendation
    let movieIndex: Int
    let totalMovies: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case roomId = "room_id"
        case movie
        case movieIndex = "movie_index"
        case totalMovies = "total_movies"
    }
}

struct WebSocketVoteConfirmedMessage: Codable {
    let type: String
    let movieId: String
    let vote: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case movieId = "movie_id"
        case vote
    }
}

struct WebSocketVotingResultMessage: Codable {
    let type: String
    let roomId: String
    let winner: RoomRecommendation
    let score: Double
    let allScores: [String: Double]
    let totalParticipants: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case roomId = "room_id"
        case winner
        case score
        case allScores = "all_scores"
        case totalParticipants = "total_participants"
    }
}

struct WebSocketErrorMessage: Codable {
    let type: String
    let message: String
} 