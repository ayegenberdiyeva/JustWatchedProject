import SwiftUI

struct MovieDetailCard: View {
    let movie: Movie
    @State private var showAddReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let posterPath = movie.posterPath {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(maxWidth: .infinity, maxHeight: 300)
                .cornerRadius(12)
            }
            Text(movie.title)
                .font(.title)
                .bold()
            if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                Text("Release Date: \(releaseDate)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let overview = movie.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .padding(.top, 8)
            }
            Spacer()
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
        .sheet(isPresented: $showAddReview) {
            AddReviewView(selectedMovie: movie)
        }
    }
} 