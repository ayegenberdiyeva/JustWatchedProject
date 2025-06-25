import Foundation

@MainActor
class AddReviewViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var success: Bool = false
    
    private let networkService = NetworkService.shared
    
    func submitReview(movieId: String, rating: Int, content: String?) async {
        isLoading = true
        error = nil
        
        do {
            let request = ReviewRequest(
                movieId: movieId,
                rating: rating,
                content: content?.isEmpty == true ? nil : content,
                watchedDate: nil
            )
            try await networkService.postReview(review: request)
            success = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
} 