import Foundation

@MainActor
class SearchResultsViewModel: ObservableObject {
    @Published var movies: [MovieSearchResult] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let networkService = NetworkService.shared
    private var searchTask: Task<Void, Never>?
    
    func searchMovies(query: String) async {
        // Cancel any existing search
        searchTask?.cancel()
        
        // If query is empty, clear results
        if query.isEmpty {
            movies = []
            return
        }
        
        // Create new search task
        searchTask = Task {
            // Add a small delay to avoid too many requests while typing
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Check if task was cancelled during delay
            if Task.isCancelled { return }
            
            isLoading = true
            do {
                self.movies = try await networkService.searchMoviesV2(query: query)
            } catch {
                self.error = error
                self.movies = []
            }
            isLoading = false
        }
        
        // Wait for the task to complete
        await searchTask?.value
    }
} 