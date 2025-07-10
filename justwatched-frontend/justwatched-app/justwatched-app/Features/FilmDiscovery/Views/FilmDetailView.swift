import SwiftUI

struct FilmDetailView: View {
    let movieId: String
    let movieTitle: String
    let posterPath: String?
    let mediaType: String
    
    @State private var showAddReview = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Poster
                        if let posterPath = posterPath {
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "film")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 48))
                                    )
                            }
                            .frame(maxWidth: 300)
                            .cornerRadius(16)
                        }
                        
                        // Title
                        Text(movieTitle)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            WatchlistButton(
                                mediaId: movieId,
                                mediaType: mediaType,
                                mediaTitle: movieTitle,
                                posterPath: posterPath
                            )
                            
                            Button(action: { showAddReview = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add Review")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.8))
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showAddReview) {
                if mediaType == "movie" {
                    // Create Movie object
                    let movie = Movie(
                        id: Int(movieId) ?? 0,
                        title: movieTitle,
                        posterPath: posterPath,
                        releaseDate: nil,
                        overview: nil
                    )
                    AddReviewView(
                        selectedMovie: movie,
                        onReviewAdded: {
                            showAddReview = false
                        }
                    )
                } else {
                    // Create TVShow object
                    let tvShow = TVShow(
                        id: Int(movieId) ?? 0,
                        name: movieTitle,
                        posterPath: posterPath,
                        firstAirDate: nil,
                        overview: nil
                    )
                    AddReviewView(
                        selectedTVShow: tvShow,
                        onReviewAdded: {
                            showAddReview = false
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    FilmDetailView(
        movieId: "123",
        movieTitle: "Inception",
        posterPath: "/poster.jpg",
        mediaType: "movie"
    )
} 