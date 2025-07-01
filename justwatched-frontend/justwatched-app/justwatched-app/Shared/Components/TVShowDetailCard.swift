import SwiftUI

struct TVShowDetailCard: View {
    let show: TVShow
    @State private var showAddReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let posterPath = show.posterPath {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(maxWidth: .infinity, maxHeight: 300)
                .cornerRadius(12)
            }
            Text(show.name)
                .font(.title)
                .bold()
            if let firstAirDate = show.firstAirDate, !firstAirDate.isEmpty {
                Text("First Air Date: \(firstAirDate)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let overview = show.overview, !overview.isEmpty {
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
            AddReviewView(selectedTVShow: show)
        }
    }
} 