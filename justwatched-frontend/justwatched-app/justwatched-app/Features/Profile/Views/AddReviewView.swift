import SwiftUI

struct AddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddReviewViewModel
    @State private var showError = false
    @State private var showSuccess = false
    
    // Callback to notify parent of successful review addition
    var onReviewAdded: (() -> Void)?
    
    init(selectedMovie: MovieSearchResult? = nil, onReviewAdded: (() -> Void)? = nil) {
        let viewModel = AddReviewViewModel()
        if let movie = selectedMovie {
            viewModel.selectedMovie = movie
            viewModel.searchText = movie.title
        }
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onReviewAdded = onReviewAdded
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                if viewModel.selectedMovie == nil {
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
                    if viewModel.selectedMovie != nil {
                        Button("Save") {
                            Task {
                                await viewModel.submitReview()
                                if viewModel.success {
                                    // Reset all fields after successful save
                                    viewModel.selectedMovie = nil
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
            .onChange(of: viewModel.error) {
                showError = viewModel.error != nil
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
            TextField("Search for a movie...", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) {
                    Task { await viewModel.searchMovies() }
                }
            if viewModel.selectedMovie != nil {
                Button(action: {
                    viewModel.selectedMovie = nil
                    viewModel.searchText = ""
                    viewModel.searchResults = []
                    viewModel.rating = 0
                    viewModel.reviewText = ""
                }) {
                    Text("Change Movie")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
        }
        .padding(.vertical, 8)
    }

    private var searchResultsList: some View {
        List(viewModel.searchResults, id: \.id) { movie in
            Button(action: {
                viewModel.selectedMovie = movie
                viewModel.searchText = movie.title
            }) {
                HStack(spacing: 12) {
                    if let posterPath = movie.posterPath {
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 40, height: 60)
                        .cornerRadius(6)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(movie.title)
                            .font(.headline)
                        if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                            Text(String(releaseDate.prefix(4)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let overview = movie.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let movie = viewModel.selectedMovie {
                HStack(alignment: .top, spacing: 12) {
                    if let posterPath = movie.posterPath {
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 40, height: 60)
                        .cornerRadius(6)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(movie.title)
                            .font(.headline)
                        if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                            Text(String(releaseDate.prefix(4)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
            TextEditor(text: $viewModel.reviewText)
                .frame(height: 100)
                .accessibilityLabel("Review text")
                .accessibilityHint("Write your review of the movie")
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }
}

#Preview {
    AddReviewView()
} 
 