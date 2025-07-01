import SwiftUI
import Foundation

struct AddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddReviewViewModel
    @State private var showError = false
    @State private var showSuccess = false
    
    // Callback to notify parent of successful review addition
    var onReviewAdded: (() -> Void)?
    
    init(selectedMovie: Movie? = nil, selectedTVShow: TVShow? = nil, onReviewAdded: (() -> Void)? = nil) {
        let viewModel = AddReviewViewModel()
        if let movie = selectedMovie {
            viewModel.selectedMovie = movie
            viewModel.searchText = movie.title
        } else if let show = selectedTVShow {
            viewModel.selectedTVShow = show
            viewModel.searchText = show.name
        }
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onReviewAdded = onReviewAdded
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                if viewModel.selectedMovie == nil && viewModel.selectedTVShow == nil {
                    searchResultsList
                } else {
                    reviewForm
                }
            }
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.selectedMovie != nil || viewModel.selectedTVShow != nil {
                        Button("Save") {
                            Task {
                                await viewModel.submitReview()
                                if viewModel.success {
                                    // Reset all fields after successful save
                                    viewModel.selectedMovie = nil
                                    viewModel.selectedTVShow = nil
                                    viewModel.rating = 0
                                    viewModel.reviewText = ""
                                    viewModel.searchText = ""
                                    viewModel.searchResults = []
                                    showSuccess = true
                                }
                            }
                        }
                        .disabled(viewModel.rating == 0 || viewModel.isLoading)
                        .overlay {
                            if viewModel.isLoading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "Unknown error")
            }
            .onChange(of: viewModel.error) { _, newValue in
                showError = newValue != nil
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    onReviewAdded?()
                    dismiss()
                }
            } message: {
                Text("Your review was saved successfully.")
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search for a movie or TV show...", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) { _, _ in
                    Task { await viewModel.searchMoviesAndTVShows() }
                }
            if viewModel.selectedMovie != nil || viewModel.selectedTVShow != nil {
                Button(action: {
                    viewModel.selectedMovie = nil
                    viewModel.selectedTVShow = nil
                    viewModel.searchText = ""
                    viewModel.searchResults = []
                    viewModel.rating = 0
                    viewModel.reviewText = ""
                }) {
                    Text("Change")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
        }
        .padding(.vertical, 8)
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.searchResults, id: \.id) { result in
                    Button(action: {
                        switch result {
                        case .movie(let movie):
                            viewModel.selectedMovie = movie
                            viewModel.searchText = movie.title
                        case .tvShow(let show):
                            viewModel.selectedTVShow = show
                            viewModel.searchText = show.name
                        }
                    }) {
                        HStack(spacing: 12) {
                            if let posterPath = result.posterPath {
                                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 40, height: 60)
                                .cornerRadius(6)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.headline)
                                if let releaseDate = result.releaseDate {
                                    Text(String(releaseDate.prefix(4)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let overview = result.overview, !overview.isEmpty {
                                    Text(overview)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let movie = viewModel.selectedMovie {
                mediaPreview(title: movie.title, releaseDate: movie.releaseDate, posterPath: movie.posterPath)
            } else if let show = viewModel.selectedTVShow {
                mediaPreview(title: show.name, releaseDate: show.firstAirDate, posterPath: show.posterPath)
            }
            
            Text("Your Rating")
                .font(.subheadline)
            HStack {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= viewModel.rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            viewModel.rating = index
                        }
                }
            }
            Text("Your Review")
                .font(.subheadline)
            
            TextField("Write your review here...", text: $viewModel.reviewText, axis: .vertical)
                .lineLimit(5...10)
                .textFieldStyle(.roundedBorder)
                .frame(height: 100)
                .accessibilityLabel("Review text")
                .accessibilityHint("Write your review")
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }
    
    private func mediaPreview(title: String, releaseDate: String?, posterPath: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let posterPath = posterPath {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 40, height: 60)
                .cornerRadius(6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let releaseDate = releaseDate, !releaseDate.isEmpty {
                    Text(String(releaseDate.prefix(4)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    AddReviewView()
} 
 