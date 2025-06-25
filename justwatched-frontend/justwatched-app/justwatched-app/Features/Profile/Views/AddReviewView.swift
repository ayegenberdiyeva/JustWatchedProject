import SwiftUI

struct AddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddReviewViewModel()
    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    @State private var movieTitle: String
    @State private var movieId: String
    @State private var showMovieSearch: Bool
    @State private var showError = false
    
    // Callback to notify parent of successful review addition
    var onReviewAdded: (() -> Void)?
    
    init(movieId: String = "", movieTitle: String = "", showMovieSearch: Bool = false, onReviewAdded: (() -> Void)? = nil) {
        _movieId = State(initialValue: movieId)
        _movieTitle = State(initialValue: movieTitle)
        _showMovieSearch = State(initialValue: showMovieSearch)
        self.onReviewAdded = onReviewAdded
    }
    
    var body: some View {
        NavigationView {
            Form {
                movieSection
                ratingSection
                reviewSection
            }
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.submitReview(
                                movieId: movieId,
                                rating: rating,
                                content: reviewText
                            )
                            if viewModel.success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(movieId.isEmpty || rating == 0 || viewModel.isLoading)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .sheet(isPresented: $showMovieSearch) {
                SearchResultsView { selectedMovie in
                    movieId = selectedMovie.id
                    movieTitle = selectedMovie.title
                    showMovieSearch = false
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
            .onChange(of: viewModel.success) { success in
                if success {
                    onReviewAdded?() // Notify parent of successful review addition
                    dismiss()
                }
            }
        }
    }

    private var movieSection: some View {
        Section(header: Text("Movie")) {
            HStack {
                Text(movieTitle.isEmpty ? "Select a movie" : movieTitle)
                    .foregroundColor(movieTitle.isEmpty ? .gray : .primary)
                Spacer()
                Button(action: { showMovieSearch = true }) {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }

    private var ratingSection: some View {
        Section(header: Text("Rating")) {
            HStack {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            rating = index
                        }
                }
            }
        }
    }

    private var reviewSection: some View {
        Section(header: Text("Review")) {
            TextEditor(text: $reviewText)
                .frame(height: 100)
                .accessibilityLabel("Review text")
                .accessibilityHint("Write your review of the movie")
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
        }
    }
}

#Preview {
    AddReviewView(movieId: "1", movieTitle: "Inception")
} 