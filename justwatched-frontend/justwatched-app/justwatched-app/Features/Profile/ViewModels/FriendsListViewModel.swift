import Foundation
import SwiftUI

@MainActor
class FriendsListViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var userDisplayNames: [String: String] = [:]
    
    private let friendsService = FriendsService.shared
    private let cacheManager = CacheManager.shared
    
    private func fetchDisplayName(for userId: String) async -> String {
        if let cached = userDisplayNames[userId] { return cached }
        do {
            let profile = try await NetworkService.shared.getOtherUserProfile(userId: userId)
            await MainActor.run { userDisplayNames[userId] = profile.displayName ?? userId }
            return profile.displayName ?? userId
        } catch {
            return userId
        }
    }
    
    func loadFriends() async {
        // First, try to load from cache
        if let cachedFriends = cacheManager.getCachedFriendsList() {
            // Convert UserProfile to Friend objects
            self.friends = cachedFriends.map { userProfile in
                Friend(
                    user_id: userProfile.userId,
                    display_name: userProfile.displayName ?? "Unknown",
                    color: userProfile.color ?? "white"
                )
            }
        }
        
        isLoading = true; error = nil
        do {
            friends = try await friendsService.getFriends()
            
            // Cache the friends list (convert to UserProfile objects for caching)
            let userProfiles = friends.map { friend in
                UserProfile(
                    userId: friend.user_id,
                    displayName: friend.display_name,
                    email: nil,
                    bio: nil,
                    color: friend.color,
                    createdAt: nil,
                    personalRecommendations: nil,
                    isFriend: true
                )
            }
            cacheManager.cacheFriendsList(userProfiles)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func loadPendingRequests() async {
        isLoading = true; error = nil
        do {
            pendingRequests = try await friendsService.getPendingRequests()
            
            // Separate requests by type
            incomingRequests = pendingRequests.filter { $0.status == "pending_received" }
            sentRequests = pendingRequests.filter { $0.status == "pending_sent" }
            
            // Fetch display names for all relevant user IDs
            let userIds = Set(incomingRequests.map { $0.from_user_id } + sentRequests.map { $0.to_user_id })
            await withTaskGroup(of: Void.self) { group in
                for userId in userIds {
                    group.addTask { _ = await self.fetchDisplayName(for: userId) }
                }
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func respondToRequest(requestId: String, action: String) async {
        isLoading = true; error = nil
        do {
            try await friendsService.respondToRequest(requestId: requestId, action: action)
            // Remove from all request lists
            pendingRequests.removeAll { $0.request_id == requestId }
            incomingRequests.removeAll { $0.request_id == requestId }
            sentRequests.removeAll { $0.request_id == requestId }
            
            if action == "accept" {
                await loadFriends()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func cancelSentRequest(requestId: String) async {
        isLoading = true; error = nil
        do {
            try await friendsService.cancelFriendRequest(requestId: requestId)
            sentRequests.removeAll { $0.request_id == requestId }
            pendingRequests.removeAll { $0.request_id == requestId }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 