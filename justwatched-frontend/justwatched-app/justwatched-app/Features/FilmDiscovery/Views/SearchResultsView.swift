import SwiftUI
import Foundation

struct SearchType: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
    
    init(label: String, value: String) {
        self.label = label
        self.value = value
        self.id = value
    }
}

struct SearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchResultsViewModel()
    @State private var searchText = ""
    
    let searchTypes: [SearchType] = [
        SearchType(label: "Movies", value: "movie"),
        SearchType(label: "TV Shows", value: "tv")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NavigationView {
                VStack(spacing: 0) {
                    Picker("Search Type", selection: $viewModel.searchType) {
                        ForEach(searchTypes) { type in
                            Text(type.label).tag(type.value)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .onChange(of: viewModel.searchType) { oldValue, newValue in
                        if !searchText.isEmpty {
                            Task { await viewModel.searchMovies(query: searchText) }
                        }
                    }
                    if searchText.isEmpty {
                        if viewModel.searchHistory.isEmpty {
                            Spacer()
                            Text("No search history found.")
                                .foregroundColor(Color(hex: "393B3D"))
                                .font(.subheadline)
                            Spacer()
                        } else {
                            List {
                                Section(header: Text("Recent Searches")) {
                                    ForEach(viewModel.searchHistory) { entry in
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(Color(hex: "393B3D"))
                                            Text(entry.query)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(entry.searchType.capitalized)
                                                .foregroundColor(Color(hex: "393B3D"))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        List {
                            if viewModel.isLoading {
                                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if !viewModel.results.isEmpty {
                                ForEach(viewModel.results) { result in
                                    NavigationLink(destination: {
                                        switch result {
                                        case .movie(let movie):
                                            MovieDetailCard(movie: movie)
                                        case .tvShow(let show):
                                            TVShowDetailCard(show: show)
                                        }
                                    }) {
                                        switch result {
                                        case .movie(let movie):
                                            HStack(alignment: .top, spacing: 12) {
                                                if let posterPath = movie.posterPath {
                                                    AsyncImage(url: posterPath.posterURL(size: "w200")) { image in
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
                                                        .foregroundColor(.white)
                                                    if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                                                        Text(String(releaseDate.prefix(4)))
                                                            .font(.subheadline)
                                                            .foregroundColor(Color(hex: "393B3D"))
                                                    }
                                                    if let overview = movie.overview, !overview.isEmpty {
                                                        Text(overview)
                                                            .font(.caption)
                                                            .foregroundColor(Color(hex: "393B3D"))
                                                            .lineLimit(3)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        case .tvShow(let show):
                                            HStack(alignment: .top, spacing: 12) {
                                                if let posterPath = show.posterPath {
                                                    AsyncImage(url: posterPath.posterURL(size: "w200")) { image in
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
                                                    Text(show.name)
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                    if let firstAirDate = show.firstAirDate, !firstAirDate.isEmpty {
                                                        Text(String(firstAirDate.prefix(4)))
                                                            .font(.subheadline)
                                                            .foregroundColor(Color(hex: "393B3D"))
                                                    }
                                                    if let overview = show.overview, !overview.isEmpty {
                                                        Text(overview)
                                                            .font(.caption)
                                                            .foregroundColor(Color(hex: "393B3D"))
                                                            .lineLimit(3)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            } else if !searchText.isEmpty {
                                Text("No results found")
                                    .foregroundColor(Color(hex: "393B3D"))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "Search for movies or shows")
                .onChange(of: searchText) { oldValue, newValue in
                    Task { await viewModel.searchMovies(query: newValue) }
                }
                .onAppear {
                    Task { await viewModel.fetchSearchHistory() }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            if AuthManager.shared.isAuthenticated {
                try? await AuthManager.shared.refreshUserProfile()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

struct MovieDetailView: View {
    let movie: Movie
    @State private var showAddReview = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let posterPath = movie.posterPath {
                    AsyncImage(url: posterPath.posterURL(size: "w500")) { image in
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
                        .foregroundColor(Color(hex: "393B3D"))
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