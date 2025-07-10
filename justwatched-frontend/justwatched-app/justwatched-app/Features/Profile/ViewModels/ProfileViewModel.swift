import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var reviews: [Review] = []
    @Published var watchlistCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    @Published var displayName: String = ""
    @Published var email: String = ""

    private let networkService = NetworkService.shared
    private let authManager = AuthManager.shared
    private let watchlistService = WatchlistService.shared
    
    init() {
        // Initialize with current auth manager state
        self.userProfile = authManager.userProfile
        self.displayName = userProfile?.displayName ?? ""
        self.email = userProfile?.email ?? ""
        
        // Fetch fresh data on initialization
        Task {
            await fetchProfile()
        }
    }
    
    func fetchProfile() async {
        isLoading = true
        error = nil
        
        do {
            // Always fetch fresh profile from AuthManager
            try await authManager.refreshUserProfile()
            self.userProfile = authManager.userProfile
            self.displayName = userProfile?.displayName ?? ""
            self.email = userProfile?.email ?? ""
            
            // Fetch reviews
            let fetchedReviews = try await networkService.fetchUserReviews()
            self.reviews = fetchedReviews
            
            // Fetch watchlist count
            if let jwt = authManager.jwt {
                do {
                    let watchlistResponse = try await watchlistService.getWatchlist(jwt: jwt)
                    self.watchlistCount = watchlistResponse.totalCount
                } catch {
                    // If watchlist fetch fails, set count to 0
                    self.watchlistCount = 0
                }
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func signOut() {
        authManager.signOut()
    }
} 
