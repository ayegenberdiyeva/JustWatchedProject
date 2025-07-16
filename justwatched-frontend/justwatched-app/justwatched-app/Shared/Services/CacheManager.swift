import Foundation
import SwiftUI

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    private let defaults = UserDefaults.standard
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let recommendations = "cached_recommendations"
        static let userReviews = "cached_user_reviews"
        static let userCollections = "cached_user_collections"
        static let friendsList = "cached_friends_list"
        static let watchlist = "cached_watchlist"
        static let friendsReviews = "cached_friends_reviews"
        static let userRooms = "cached_user_rooms"
        static let roomRecommendations = "cached_room_recommendations_"
        static let lastUpdateTime = "last_update_time_"
    }
    
    // MARK: - Generic Cache Methods
    private func isCacheValid(for key: String) -> Bool {
        let lastUpdate = defaults.object(forKey: CacheKeys.lastUpdateTime + key) as? Date ?? Date.distantPast
        return Date().timeIntervalSince(lastUpdate) < cacheExpiration
    }
    
    private func updateCacheTimestamp(for key: String) {
        defaults.set(Date(), forKey: CacheKeys.lastUpdateTime + key)
    }
    
    // MARK: - Recommendations Cache
    func getCachedRecommendations() -> [Movie]? {
        guard isCacheValid(for: CacheKeys.recommendations) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.recommendations) else { return nil }
        return try? JSONDecoder().decode([Movie].self, from: data)
    }
    
    func cacheRecommendations(_ recommendations: [Movie]) {
        if let data = try? JSONEncoder().encode(recommendations) {
            defaults.set(data, forKey: CacheKeys.recommendations)
            updateCacheTimestamp(for: CacheKeys.recommendations)
        }
    }
    
    // MARK: - User Reviews Cache
    func getCachedUserReviews() -> [Review]? {
        guard isCacheValid(for: CacheKeys.userReviews) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.userReviews) else { return nil }
        return try? JSONDecoder().decode([Review].self, from: data)
    }
    
    func cacheUserReviews(_ reviews: [Review]) {
        if let data = try? JSONEncoder().encode(reviews) {
            defaults.set(data, forKey: CacheKeys.userReviews)
            updateCacheTimestamp(for: CacheKeys.userReviews)
        }
    }
    
    // MARK: - User Collections Cache
    func getCachedUserCollections() -> [Collection]? {
        guard isCacheValid(for: CacheKeys.userCollections) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.userCollections) else { return nil }
        return try? JSONDecoder().decode([Collection].self, from: data)
    }
    
    func cacheUserCollections(_ collections: [Collection]) {
        if let data = try? JSONEncoder().encode(collections) {
            defaults.set(data, forKey: CacheKeys.userCollections)
            updateCacheTimestamp(for: CacheKeys.userCollections)
        }
    }
    
    // MARK: - Friends List Cache
    func getCachedFriendsList() -> [UserProfile]? {
        guard isCacheValid(for: CacheKeys.friendsList) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.friendsList) else { return nil }
        return try? JSONDecoder().decode([UserProfile].self, from: data)
    }
    
    func cacheFriendsList(_ friends: [UserProfile]) {
        if let data = try? JSONEncoder().encode(friends) {
            defaults.set(data, forKey: CacheKeys.friendsList)
            updateCacheTimestamp(for: CacheKeys.friendsList)
        }
    }
    
    // MARK: - Watchlist Cache
    func getCachedWatchlist() -> [WatchlistItem]? {
        guard isCacheValid(for: CacheKeys.watchlist) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.watchlist) else { return nil }
        return try? JSONDecoder().decode([WatchlistItem].self, from: data)
    }
    
    func cacheWatchlist(_ watchlist: [WatchlistItem]) {
        if let data = try? JSONEncoder().encode(watchlist) {
            defaults.set(data, forKey: CacheKeys.watchlist)
            updateCacheTimestamp(for: CacheKeys.watchlist)
        }
    }
    
    // MARK: - Friends Reviews Cache
    func getCachedFriendsReviews() -> FriendsReviewsResponse? {
        guard isCacheValid(for: CacheKeys.friendsReviews) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.friendsReviews) else { return nil }
        return try? JSONDecoder().decode(FriendsReviewsResponse.self, from: data)
    }
    
    func cacheFriendsReviews(_ friendsReviews: FriendsReviewsResponse) {
        if let data = try? JSONEncoder().encode(friendsReviews) {
            defaults.set(data, forKey: CacheKeys.friendsReviews)
            updateCacheTimestamp(for: CacheKeys.friendsReviews)
        }
    }
    
    // MARK: - User Rooms Cache
    func getCachedUserRooms() -> [Room]? {
        guard isCacheValid(for: CacheKeys.userRooms) else { return nil }
        guard let data = defaults.data(forKey: CacheKeys.userRooms) else { return nil }
        return try? JSONDecoder().decode([Room].self, from: data)
    }
    
    func cacheUserRooms(_ rooms: [Room]) {
        if let data = try? JSONEncoder().encode(rooms) {
            defaults.set(data, forKey: CacheKeys.userRooms)
            updateCacheTimestamp(for: CacheKeys.userRooms)
        }
    }
    
    // MARK: - Room Recommendations Cache
    func getCachedRoomRecommendations(for roomId: String) -> [Movie]? {
        let key = CacheKeys.roomRecommendations + roomId
        guard isCacheValid(for: key) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([Movie].self, from: data)
    }
    
    func cacheRoomRecommendations(_ recommendations: [Movie], for roomId: String) {
        let key = CacheKeys.roomRecommendations + roomId
        if let data = try? JSONEncoder().encode(recommendations) {
            defaults.set(data, forKey: key)
            updateCacheTimestamp(for: key)
        }
    }
    
    // MARK: - Cache Management
    func clearAllCache() {
        let keys = [
            CacheKeys.recommendations,
            CacheKeys.userReviews,
            CacheKeys.userCollections,
            CacheKeys.friendsList,
            CacheKeys.watchlist,
            CacheKeys.friendsReviews,
            CacheKeys.userRooms
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: CacheKeys.lastUpdateTime + key)
        }
        
        // Clear room-specific caches
        let allKeys = defaults.dictionaryRepresentation().keys
        let roomKeys = allKeys.filter { $0.hasPrefix(CacheKeys.roomRecommendations) }
        for key in roomKeys {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: CacheKeys.lastUpdateTime + key)
        }
    }
    
    func clearCache(for key: String) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: CacheKeys.lastUpdateTime + key)
    }
}

// MARK: - Cacheable Protocol
protocol Cacheable: Codable {
    static var cacheKey: String { get }
}

// MARK: - Cache Extensions for Models
extension Movie: Cacheable {
    static var cacheKey: String { "movie" }
}

extension Review: Cacheable {
    static var cacheKey: String { "review" }
}

extension Collection: Cacheable {
    static var cacheKey: String { "collection" }
}

extension UserProfile: Cacheable {
    static var cacheKey: String { "user_profile" }
}

extension WatchlistItem: Cacheable {
    static var cacheKey: String { "watchlist_item" }
}

extension FriendsReviewsResponse: Cacheable {
    static var cacheKey: String { "friends_reviews" }
}

extension Room: Cacheable {
    static var cacheKey: String { "room" }
} 