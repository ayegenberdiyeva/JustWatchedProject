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
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var success: Bool = false
    
    private let networkService = NetworkService.shared
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
                watchedDate: Date(),
                mediaTitle: selectedMovie?.title ?? selectedTVShow?.name,
                posterPath: selectedMovie?.posterPath ?? selectedTVShow?.posterPath
            )
            try await networkService.postReview(review: reviewRequest)
            success = true
        } catch {
            self.error = error.localizedDescription
            success = false
        }
    }
} 