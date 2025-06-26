import Foundation
import SwiftUI

@MainActor
class AddReviewViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [MovieSearchResult] = []
    @Published var selectedMovie: MovieSearchResult? = nil
    @Published var rating: Int = 0
    @Published var reviewText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var success: Bool = false
    
    private let networkService = NetworkService.shared
    private var searchTask: Task<Void, Never>?
    
    func searchMovies() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            searchResults = try await networkService.searchMoviesV2(query: searchText)
        } catch {
            self.error = error.localizedDescription
            searchResults = []
        }
    }
    
    func submitReview() async {
        guard let movie = selectedMovie else {
            error = "Please select a movie."
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
            // Replace with your backend review submission logic
            let reviewRequest = ReviewRequest(
                movieId: String(movie.id),
                rating: rating,
                content: reviewText,
                watchedDate: Date()
            )
            try await networkService.postReview(review: reviewRequest)
            success = true
        } catch {
            self.error = error.localizedDescription
            success = false
        }
    }
} 