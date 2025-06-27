import SwiftUI

struct SearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchResultsViewModel()
    @State private var searchText = ""
    @State private var selectedMovie: MovieSearchResult? = nil
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.movies.isEmpty {
                    ForEach(viewModel.movies) { movie in
                        Button(action: { selectedMovie = movie }) {
                            HStack(alignment: .top, spacing: 12) {
                                if let posterPath = movie.posterPath {
                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 60, height: 90)
                                    .cornerRadius(8)
                                } else {
                                    Color.gray.opacity(0.2)
                                        .frame(width: 60, height: 90)
                                        .cornerRadius(8)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(movie.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                                        Text(String(releaseDate.prefix(4)))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    if let overview = movie.overview, !overview.isEmpty {
                                        Text(overview)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else if !searchText.isEmpty {
                    Text("No movies found")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search Movies")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search for movies")
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel("Search movies")
                .accessibilityHint("Enter movie title to search")
                .onChange(of: searchText) {
                    Task {
                        await viewModel.searchMovies(query: searchText)
                    }
                }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedMovie) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }
}

struct MovieDetailView: View {
    let movie: MovieSearchResult
    @State private var showAddReview = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let posterPath = movie.posterPath {
                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .cornerRadius(12)
                }
                Text(movie.title)
                    .font(.title)
                    .bold()
                if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                    Text("Release Year: \(String(releaseDate.prefix(4)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.body)
                        .padding(.top, 8)
                }
                Button(action: { showAddReview = true }) {
                    Label("Add Review", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showAddReview) {
            AddReviewView(selectedMovie: movie)
        }
    }
}

#Preview {
    SearchResultsView()
} 