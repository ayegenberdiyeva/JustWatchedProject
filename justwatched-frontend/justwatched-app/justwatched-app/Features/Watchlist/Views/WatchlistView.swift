import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel = WatchlistViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showAddReview = false
    @State private var selectedItem: WatchlistItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading your watchlist...")
                            .foregroundColor(.white)
                            .padding(.top, 16)
                    }
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Error loading watchlist")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(error.localizedDescription)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.fetchWatchlist()
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                } else if viewModel.watchlistItems.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "film")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("Your Watchlist is Empty")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Start adding movies and TV shows to your watchlist to see them here.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Discover Movies") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.watchlistItems) { item in
                                WatchlistItemCard(
                                    item: item,
                                    onRemove: {
                                        Task {
                                            await viewModel.removeFromWatchlist(mediaId: item.mediaId)
                                        }
                                    },
                                    onMarkWatched: {
                                        selectedItem = item
                                        showAddReview = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("My Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshWatchlist()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddReview) {
                if let item = selectedItem {
                    if item.mediaType == "movie" {
                        // Create Movie object
                        let movie = Movie(
                            id: Int(item.mediaId) ?? 0,
                            title: item.mediaTitle,
                            posterPath: item.posterPath,
                            releaseDate: nil,
                            overview: nil
                        )
                        AddReviewView(
                            selectedMovie: movie,
                            onReviewAdded: {
                                Task {
                                    // Remove from watchlist after adding review
                                    await viewModel.removeFromWatchlist(mediaId: item.mediaId)
                                    showAddReview = false
                                }
                            }
                        )
                    } else {
                        // Create TVShow object
                        let tvShow = TVShow(
                            id: Int(item.mediaId) ?? 0,
                            name: item.mediaTitle,
                            posterPath: item.posterPath,
                            firstAirDate: nil,
                            overview: nil
                        )
                        AddReviewView(
                            selectedTVShow: tvShow,
                            onReviewAdded: {
                                Task {
                                    // Remove from watchlist after adding review
                                    await viewModel.removeFromWatchlist(mediaId: item.mediaId)
                                    showAddReview = false
                                }
                            }
                        )
                    }
                }
            }
            .task {
                await viewModel.fetchWatchlist()
            }
        }
    }
}

struct WatchlistItemCard: View {
    let item: WatchlistItem
    let onRemove: () -> Void
    let onMarkWatched: () -> Void
    
    @State private var showRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Poster
            if let posterPath = item.posterPath {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w154\(posterPath)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                    )
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.mediaTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(item.mediaType.uppercased())
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text("Added \(formatDate(item.addedAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onMarkWatched) {
                        Label("Mark Watched", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { showRemoveAlert = true }) {
                        Label("Remove", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
        .alert("Remove from Watchlist", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove '\(item.mediaTitle)' from your watchlist?")
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return "recently"
    }
}

#Preview {
    WatchlistView()
} 