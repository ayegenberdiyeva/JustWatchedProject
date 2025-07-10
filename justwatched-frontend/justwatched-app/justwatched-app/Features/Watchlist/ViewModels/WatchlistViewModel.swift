import Foundation
import SwiftUI

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var watchlistItems: [WatchlistItem] = []
    @Published var isLoading = false
    @Published var error: LocalizedError?
    @Published var totalCount = 0
    
    private let watchlistService = WatchlistService.shared
    private let authManager = AuthManager.shared
    
    func fetchWatchlist() async {
        guard let jwt = authManager.jwt else {
            error = WatchlistError.itemNotInWatchlist // Use as generic error
            return
        }
        
        // Debug: Check if user is authenticated
        print("🔍 Fetching watchlist for authenticated user: \(authManager.isAuthenticated)")
        print("🔍 JWT token exists: \(jwt != nil)")
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await watchlistService.getWatchlist(jwt: jwt)
            self.watchlistItems = response.items
            self.totalCount = response.totalCount
        } catch let e as LocalizedError {
            print("❌ Watchlist error: \(e.localizedDescription)")
            self.error = e
        } catch {
            print("❌ Watchlist error: \(error)")
            self.error = WatchlistServiceError.requestFailed(statusCode: 500)
        }
    }
    
    func addToWatchlist(mediaId: String, mediaType: String, mediaTitle: String, posterPath: String?) async {
        guard let jwt = authManager.jwt else {
            self.error = WatchlistError.itemNotInWatchlist // Use as generic error
            return
        }
        
        do {
            let newItem = try await watchlistService.addToWatchlist(
                jwt: jwt,
                mediaId: mediaId,
                mediaType: mediaType,
                mediaTitle: mediaTitle,
                posterPath: posterPath
            )
            
            // Add to local array
            watchlistItems.append(newItem)
            totalCount += 1
            
        } catch let e as LocalizedError {
            self.error = e
        } catch {
            self.error = WatchlistServiceError.requestFailed(statusCode: 500)
        }
    }
    
    func removeFromWatchlist(mediaId: String) async {
        guard let jwt = authManager.jwt else {
            self.error = WatchlistError.itemNotInWatchlist // Use as generic error
            return
        }
        
        do {
            try await watchlistService.removeFromWatchlist(jwt: jwt, mediaId: mediaId)
            
            // Remove from local array
            watchlistItems.removeAll { $0.mediaId == mediaId }
            totalCount = max(0, totalCount - 1)
            
        } catch let e as LocalizedError {
            self.error = e
        } catch {
            self.error = WatchlistServiceError.requestFailed(statusCode: 500)
        }
    }
    
    func checkWatchlistStatus(mediaId: String) async -> Bool {
        guard let jwt = authManager.jwt else {
            return false
        }
        
        do {
            return try await watchlistService.checkWatchlistStatus(jwt: jwt, mediaId: mediaId)
        } catch {
            return false
        }
    }
    
    func refreshWatchlist() async {
        await fetchWatchlist()
    }
} 