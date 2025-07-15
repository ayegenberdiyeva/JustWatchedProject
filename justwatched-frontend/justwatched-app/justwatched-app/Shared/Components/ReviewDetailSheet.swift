import SwiftUI

struct ReviewDetailSheet: View {
    let review: Review
    let onReviewDeleted: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        VStack(spacing: 16) {
            if let posterPath = review.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w300")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(height: 220)
                .cornerRadius(16)
            }
            Text(review.title)
                .font(.title2).bold()
                .foregroundColor(.primary)
            Text("Rating: \(review.rating)/5")
                .font(.headline)
                .foregroundColor(.accentColor)
            if let content = review.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Watched: \(review.watchedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Added: \(review.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete button - only show if onReviewDeleted is provided (user's own reviews)
            if onReviewDeleted != nil {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Review")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isDeleting)
            }
            
            if isDeleting {
                ProgressView("Deleting...")
                    .foregroundColor(.secondary)
            }
            
            if let error = deleteError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .alert("Delete Review", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteReview()
                }
            }
        } message: {
            Text("Are you sure you want to delete this review? This action cannot be undone.")
        }
    }
    
    private func deleteReview() async {
        guard let reviewId = review.id else {
            deleteError = "Review ID not found"
            return
        }
        
        isDeleting = true
        deleteError = nil
        
        do {
            try await NetworkService.shared.deleteReview(reviewId: reviewId)
            await MainActor.run {
                isDeleting = false
                dismiss()
                onReviewDeleted?()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                deleteError = error.localizedDescription
            }
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
//         "review_text": "This is a sample review content that demonstrates how the ReviewDetailSheet looks with actual data.",
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
//         ReviewDetailSheet(
//             review: sampleReview,
//             onReviewDeleted: nil
//         )
//     } else {
//         Text("Error creating preview")
//     }
// }