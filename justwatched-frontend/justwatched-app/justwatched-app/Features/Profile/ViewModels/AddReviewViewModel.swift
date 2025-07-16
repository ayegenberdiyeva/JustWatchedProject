import Foundation
import SwiftUI

@MainActor
class AddReviewViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var selectedMovie: Movie? = nil
    @Published var selectedTVShow: TVShow? = nil
    @Published var rating: Int = 0
    @Published var reviewText: String = ""
    @Published var watchedDate: Date = Date()
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var success: Bool = false
    @Published var status: String = "watched" // "watched" or "watchlist"
    @Published var selectedCollections: Set<String> = []
    @Published var collections: [Collection] = []
    @Published var isPresentingNewCollection: Bool = false
    @Published var newCollectionName: String = ""
    @Published var newCollectionDescription: String = ""
    @Published var newCollectionVisibility: String = "private"
    
    private let networkService = NetworkService.shared
    private let cacheManager = CacheManager.shared
    private var searchTask: Task<Void, Never>?
    
    func searchMoviesAndTVShows() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            // Search for both movies and TV shows
            let movieResults = try await networkService.searchMoviesOrTV(query: searchText, searchType: "movie")
            let tvResults = try await networkService.searchMoviesOrTV(query: searchText, searchType: "tv")
            
            // Combine and sort results by popularity or relevance
            searchResults = movieResults + tvResults
        } catch {
            self.error = error.localizedDescription
            searchResults = []
        }
    }
    
    func fetchCollections() async {
        // First, try to load from cache
        if let cachedCollections = cacheManager.getCachedUserCollections() {
            self.collections = cachedCollections
        }
        
        isLoading = true
        defer { isLoading = false }
        do {
            self.collections = try await networkService.fetchUserCollections()
            
            // Cache the collections
            cacheManager.cacheUserCollections(self.collections)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func createCollection() async {
        guard !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let collection = try await networkService.createCollection(name: newCollectionName, description: newCollectionDescription.isEmpty ? nil : newCollectionDescription, visibility: newCollectionVisibility)
            collections.insert(collection, at: 0)
            selectedCollections.insert(collection.id)
            
            // Update cache
            cacheManager.cacheUserCollections(collections)
            
            newCollectionName = ""
            newCollectionDescription = ""
            newCollectionVisibility = "private"
            isPresentingNewCollection = false
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func submitReview() async {
        guard let mediaId = selectedMovie?.id ?? selectedTVShow?.id else {
            error = "Please select a movie or TV show."
            return
        }
        guard rating > 0 else {
            error = "Please provide a rating."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let reviewRequest = ReviewRequest(
                mediaId: "\(mediaId)",
                mediaType: selectedMovie != nil ? "movie" : "tv",
                rating: Double(rating),
                content: reviewText.isEmpty ? nil : reviewText,
                watchedDate: watchedDate,
                mediaTitle: selectedMovie?.title ?? selectedTVShow?.name,
                posterPath: selectedMovie?.posterPath ?? selectedTVShow?.posterPath,
                status: status,
                collections: selectedCollections.isEmpty ? nil : Array(selectedCollections)
            )
            try await networkService.postReview(review: reviewRequest)
            success = true
            
            // Clear user reviews cache to force refresh
            cacheManager.clearCache(for: "cached_user_reviews")
        } catch {
            self.error = error.localizedDescription
            success = false
        }
    }
} 