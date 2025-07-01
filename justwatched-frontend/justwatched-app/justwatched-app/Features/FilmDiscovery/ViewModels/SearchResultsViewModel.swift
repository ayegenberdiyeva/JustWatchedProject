import Foundation
import SwiftUI

struct SearchHistoryEntry: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let query: String
    let timestamp: Date
    let resultCount: Int
    let searchType: String
    let clickedResults: [String]?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case id = "search_id"
        case userId = "user_id"
        case query
        case timestamp
        case resultCount = "result_count"
        case searchType = "search_type"
        case clickedResults = "clicked_results"
        case sessionId = "session_id"
    }
}

struct SearchHistoryResponse: Codable {
    let searches: [SearchHistoryEntry]
    let totalCount: Int
    let hasMore: Bool
    enum CodingKeys: String, CodingKey {
        case searches
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

@MainActor
class SearchResultsViewModel: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchHistory: [SearchHistoryEntry] = []
    @Published var searchType: String = "movie"
    @Published var hasMoreHistory = false
    private var offset = 0
    private let limit = 20
    private let networkService = NetworkService.shared
    private var searchTask: Task<Void, Never>?
    
    func searchMovies(query: String) async {
        // Cancel any existing search
        searchTask?.cancel()
        
        // If query is empty, clear results
        if query.isEmpty {
            results = []
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
                self.results = try await networkService.searchMoviesOrTV(query: query, searchType: searchType)
            } catch {
                self.error = error
                self.results = []
            }
            isLoading = false
        }
        
        // Wait for the task to complete
        await searchTask?.value
        
        // After successful search:
        await fetchSearchHistory()
    }

    func fetchSearchHistory(reset: Bool = false) async {
        if reset {
            offset = 0
            searchHistory = []
        }
        do {
            let (entries, hasMore) = try await networkService.fetchSearchHistory(limit: limit, offset: offset)
            if reset {
                self.searchHistory = entries
            } else {
                self.searchHistory += entries
            }
            self.hasMoreHistory = hasMore
            self.offset += entries.count
        } catch {
            // Handle error (optional)
        }
    }

    func fetchMoreSearchHistory() async {
        guard hasMoreHistory else { return }
        await fetchSearchHistory(reset: false)
    }

    func deleteSearchHistoryEntry(id: String) async {
        do {
            try await networkService.deleteSearchHistoryEntry(id: id)
            await fetchSearchHistory(reset: true)
        } catch {
            // Handle error (optional)
        }
    }

    func clearSearchHistory() async {
        do {
            try await networkService.clearSearchHistory()
            self.searchHistory = []
        } catch {
            // Handle error (optional)
        }
    }
} 