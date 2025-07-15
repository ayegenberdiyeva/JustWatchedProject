import SwiftUI

struct GalleryReviewCard: View {
    let review: Review
    var onOpen: () -> Void
    @State private var navigateToReviewDetail = false
    private let reviewTruncationLimit = 50

    var body: some View {
        ZStack(alignment: .bottom) {
            // Poster
            if let posterPath = review.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w500")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 300, height: 400)
                .clipped()
                .cornerRadius(24)
            }
            // --- LIQUID GLASS EFFECT UNDER OVERLAY ---
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .frame(height: 220)
                    .frame(width: 300)
            }
            .frame(width: 300, height: 400)
            .allowsHitTesting(false)
            // --- OVERLAY CARD ---
            VStack(alignment: .leading, spacing: 6) {
                Text(review.title)
                    .font(.title2).bold()
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let content = review.content, !content.isEmpty {
                    Text(content)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    
                    // Add empty text if content is only one line to maintain spacing
                    if content.count < 50 {
                        Text("")
                            .font(.footnote)
                            .foregroundColor(.clear)
                    }
                } else {
                    Text("No review added.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.6))
                        .shadow(radius: 1)
                    Text("")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                }
                HStack(spacing: 6) {
                    VStack {
                        Text("Watched on")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(review.watchedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    VStack {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "%.1f", Double(review.rating)))
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                }
                Text("View Review")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(20)
            .frame(width: 300)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.3), Color.clear]), startPoint: .bottom, endPoint: .top)
                    .cornerRadius(24)
            )
        }
        .frame(width: 300, height: 400)
        .background(Color.white.opacity(0.01))
        .cornerRadius(24)
        .padding(.vertical, 8)
        .onTapGesture {
            navigateToReviewDetail = true
        }
        .navigationDestination(isPresented: $navigateToReviewDetail) {
            ReviewDetailSheet(review: review, onReviewDeleted: onOpen)
        }
    }
    

}

// #Preview {
//     // Create a sample review using JSON decoding
//     let sampleReviewJSON = """
//     {
//         "review_id": "1",
//         "media_id": "123",
//         "media_type": "movie",
//         "rating": 4.5,
//         "review_text": "This is a sample review content that demonstrates how the GalleryReviewCard looks with actual data.",
//         "poster_path": "/sample-poster.jpg",
//         "watched_date": "2024-01-15T10:30:00.000Z",
//         "created_at": "2024-01-15T10:30:00.000Z",
//         "media_title": "Sample Movie",
//         "status": "watched"
//     }
//     """.data(using: .utf8)!
    
//     let decoder = JSONDecoder()
//     decoder.dateDecodingStrategy = .iso8601
    
//     if let sampleReview = try? decoder.decode(Review.self, from: sampleReviewJSON) {
//         GalleryReviewCard(
//             review: sampleReview,
//             onOpen: {}
//         )
//     } else {
//         Text("Error creating preview")
//     }
// } 