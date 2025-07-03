import SwiftUI
import Foundation

struct AddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddReviewViewModel
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showAddCollection = false
    
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
            ZStack {
                // Black background with blurred poster overlay
                if let posterPath = viewModel.selectedMovie?.posterPath ?? viewModel.selectedTVShow?.posterPath {
                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 32)
                            .overlay(Color.black.opacity(0.7))
                            .ignoresSafeArea()
                    } placeholder: {
                        Color.black.ignoresSafeArea()
                    }
                } else {
                    Color.black.ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    searchBar
                    if viewModel.selectedMovie == nil && viewModel.selectedTVShow == nil {
                        searchResultsList
                    } else {
                        glassForm
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.selectedMovie = nil
                        viewModel.selectedTVShow = nil
                        viewModel.rating = 0
                        viewModel.reviewText = ""
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                        viewModel.status = "watched"
                        viewModel.selectedCollections = []
                        dismiss()
                    }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.selectedMovie != nil || viewModel.selectedTVShow != nil {
                        Button("Save") {
                            Task {
                                await viewModel.submitReview()
                                if viewModel.success {
                                    viewModel.selectedMovie = nil
                                    viewModel.selectedTVShow = nil
                                    viewModel.rating = 0
                                    viewModel.reviewText = ""
                                    viewModel.searchText = ""
                                    viewModel.searchResults = []
                                    viewModel.status = "watched"
                                    viewModel.selectedCollections = []
                                    showSuccess = true
                                }
                            }
                        }
                        .disabled(viewModel.rating == 0 || viewModel.isLoading)
                        .opacity((viewModel.rating == 0 || viewModel.isLoading) ? 0.5 : 1.0)
                        .overlay {
                            if viewModel.isLoading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .foregroundColor(preferredColor)
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
            .onAppear {
                Task { await viewModel.fetchCollections() }
            }
            .sheet(isPresented: $showAddCollection) {
                AddCollectionView(
                    preferredColor: preferredColor,
                    onComplete: { name, description, visibility in
                        Task {
                            viewModel.newCollectionName = name
                            viewModel.newCollectionDescription = description
                            viewModel.newCollectionVisibility = visibility
                            await viewModel.createCollection()
                            showAddCollection = false
                        }
                    },
                    onCancel: { showAddCollection = false }
                )
            }
            .task {
                if AuthManager.shared.isAuthenticated {
                    try? await AuthManager.shared.refreshUserProfile()
                }
            }
        }
    }

    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }

    private var searchBar: some View {
        HStack {
            ZStack(alignment: .leading) {
                if viewModel.searchText.isEmpty {
                    Text("Search for a movie or TV show...")
                        .foregroundColor(preferredColor)
                        .padding(.leading, 28)
                }
                TextField("", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.secondary.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .accentColor(preferredColor) // text cursor color
                    .padding(.horizontal)
                    .onChange(of: viewModel.searchText) { _, _ in
                        Task { await viewModel.searchMoviesAndTVShows() }
                    }
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
                        .foregroundColor(preferredColor)
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
                                    .foregroundColor(.white)
                                if let releaseDate = result.releaseDate, !releaseDate.isEmpty {
                                    Text(String(releaseDate.prefix(4)))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .background(Color.clear)
    }

    private var glassForm: some View {
        VStack(spacing: 20) {
            // Media info
            HStack(alignment: .top, spacing: 16) {
                if let posterPath = viewModel.selectedMovie?.posterPath ?? viewModel.selectedTVShow?.posterPath {
                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(10)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedMovie?.title ?? viewModel.selectedTVShow?.name ?? "")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    if let year = (viewModel.selectedMovie?.releaseDate ?? viewModel.selectedTVShow?.firstAirDate)?.prefix(4) {
                        Text(year)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            // Emoji rating
            HStack(spacing: 18) {
                ForEach(0..<5) { idx in
                    let emojis = ["😡", "😕", "😐", "🙂", "🤩"]
                    let selected = viewModel.rating == idx + 1
                    Text(emojis[idx])
                        .font(.system(size: selected ? 38 : 28))
                        .scaleEffect(selected ? 1.2 : 1.0)
                        .shadow(color: selected ? preferredColor.opacity(0.7) : .clear, radius: selected ? 8 : 0)
                        .onTapGesture { viewModel.rating = idx + 1 }
                        .animation(.spring(), value: viewModel.rating)
                }
            }
            // Watched/Watchlist picker
            HStack(spacing: 0) {
                ForEach(["watched", "watchlist"], id: \ .self) { status in
                    Button(action: { viewModel.status = status }) {
                        Text(status.capitalized)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.status == status ? preferredColor : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                ZStack {
                                    if viewModel.status == status {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(preferredColor.opacity(0.5), lineWidth: 8)
                                            .blur(radius: 6)
                                            .offset(x: 0, y: 0)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            // Review textfield
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Review")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                let textPadding = EdgeInsets(top: 10, leading: 8, bottom: 8, trailing: 8)
                ZStack(alignment: .topLeading) {
                    if viewModel.reviewText.isEmpty {
                        Text("Write your review here...")
                            .foregroundColor(.white.opacity(0.4))
                            .padding(textPadding)
                    }
                    ZStack {
                        Color.secondary.opacity(0.25)
                        TextEditor(text: $viewModel.reviewText)
                            .frame(height: 100)
                            .foregroundColor(.white)
                            .accentColor(preferredColor)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(textPadding)
                    }
                    .cornerRadius(10)
                }
            }
            // Collections
            HStack {
                Text("Collections:")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddCollection = true }) {
                    Text("+ New")
                        .foregroundColor(preferredColor)
                        .font(.subheadline.bold())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.collections) { collection in
                        Button(action: {
                            if viewModel.selectedCollections.contains(collection.id) {
                                viewModel.selectedCollections.remove(collection.id)
                            } else {
                                viewModel.selectedCollections.insert(collection.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.selectedCollections.contains(collection.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(viewModel.selectedCollections.contains(collection.id) ? preferredColor : .white.opacity(0.7))
                                Text(collection.name)
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(viewModel.selectedCollections.contains(collection.id) ? preferredColor.opacity(0.18) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(preferredColor.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(28)
        .background(Color.black.opacity(0.7).blur(radius: 0.5))
        .cornerRadius(28)
        .padding(.horizontal, 16)
        .padding(.top, 32)
    }
}

#Preview {
    AddReviewView()
} 
 