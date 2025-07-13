import Foundation
import SwiftUI

@MainActor
class ProfileFriendViewModel: ObservableObject {
    @Published var friendStatus: String? = nil // "not_friends", "pending_sent", etc.
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var pendingRequestId: String? = nil // For accept/decline
    
    private let friendsService = FriendsService.shared
    
    func checkStatus(with userId: String) async {
        isLoading = true; error = nil
        pendingRequestId = nil
        do {
            let statusResp = try await friendsService.checkStatus(with: userId)
            friendStatus = statusResp.status
            if statusResp.status == "pending_sent" {
                // Fetch all pending requests and find the one for this user (sent)
                let pending = try await friendsService.getPendingRequests()
                if let req = pending.first(where: { $0.to_user_id == userId }) {
                    pendingRequestId = req.request_id
                }
            } else if statusResp.status == "pending_received" {
                // Fetch all pending requests and find the one for this user (received)
                let pending = try await friendsService.getPendingRequests()
                if let req = pending.first(where: { $0.from_user_id == userId }) {
                    pendingRequestId = req.request_id
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func sendRequest(to userId: String) async {
        isLoading = true; error = nil
        do {
            let req = try await friendsService.sendRequest(to: userId)
            friendStatus = req.status
            pendingRequestId = req.request_id
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func removeFriend(userId: String) async {
        isLoading = true; error = nil
        do {
            try await friendsService.removeFriend(userId: userId)
            friendStatus = "not_friends"
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func respondToRequest(requestId: String, action: String) async {
        isLoading = true; error = nil
        do {
            try await friendsService.respondToRequest(requestId: requestId, action: action)
            if action == "accept" {
                friendStatus = "friends"
            } else {
                friendStatus = "not_friends"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 