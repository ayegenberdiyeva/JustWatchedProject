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
    
    private let friendsService = FriendsService.shared
    
    func loadFriends() async {
        isLoading = true; error = nil
        do {
            friends = try await friendsService.getFriends()
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
            
            print("🔍 Loaded \(incomingRequests.count) incoming requests and \(sentRequests.count) sent requests")
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