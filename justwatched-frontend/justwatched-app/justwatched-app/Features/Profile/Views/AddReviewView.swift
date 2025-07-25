import SwiftUI
import Foundation

struct AddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddReviewViewModel
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showAddCollection = false
    @State private var gradientAngle: Double = 0.0
    @FocusState private var isSearchFocused: Bool
    
    // Callback to notify parent of successful review addition
    var onReviewAdded: (() -> Void)?
    
    // Helper to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
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
        NavigationStack {
            ZStack {
                // Black background with blurred poster overlay
                if let posterPath = viewModel.selectedMovie?.posterPath ?? viewModel.selectedTVShow?.posterPath {
                    AsyncImage(url: posterPath.posterURL(size: "w500")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .blur(radius: 32)
                            .overlay(Color.black.opacity(0.7))
                            .ignoresSafeArea()
                    } placeholder: {
                        Color.black
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .ignoresSafeArea()
                    }
                } else {
                    Color.black
                        // .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .ignoresSafeArea()
                }
                VStack {
                    // Spacer(maxHeight: 10)
            VStack(spacing: 0) {
                        if viewModel.selectedMovie == nil && viewModel.selectedTVShow == nil {
                searchBar
                        } else {
                            Button(action: {
                                viewModel.selectedMovie = nil
                                viewModel.selectedTVShow = nil
                                viewModel.searchText = ""
                                viewModel.searchResults = []
                                viewModel.rating = 0
                                viewModel.reviewText = ""
                                viewModel.watchedDate = Date()
                            }) {
                                Text("Change selection")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .foregroundColor(Color.white)
                                    .cornerRadius(16)
                            }
                            .padding(.vertical, 8)
                            // .padding(.horizontal, 16)
                        }
                if viewModel.selectedMovie == nil && viewModel.selectedTVShow == nil {
                    searchResultsList
                } else {
                            glassForm
                                // .padding()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    // Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                // .ignoresSafeArea(.keyboard)
            }
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Back button removed
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Placeholder for the removed Save button
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
        .toolbar(.hidden, for: .tabBar)
    }

    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .red
        }
    }
    
    private var animatedPlaceholderText: some View {
        let colorValue = AuthManager.shared.userProfile?.color ?? "red"
        return Text("Search for a movie or TV show...")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(colors: AnimatedPaletteGradientBackground.palette(for: colorValue)),
                    center: .topTrailing,
                    startAngle: .degrees(gradientAngle),
                    endAngle: .degrees(gradientAngle + 360)
                )
            )
            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
    }

    private var searchBar: some View {
        HStack {
            ZStack(alignment: .leading) {
                TextField(
                    "",
                    text: $viewModel.searchText
                )
                .focused($isSearchFocused)
                .onSubmit {
                    isSearchFocused = false
                }
                .padding()
                .background(.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(20)
                
                if viewModel.searchText.isEmpty {
                    animatedPlaceholderText
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)
            .onChange(of: viewModel.searchText) { _, _ in
                Task { await viewModel.searchMoviesAndTVShows() }
            }
            .onAppear {
                // Start gradient animation
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    gradientAngle += 1.0
                }
            }
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .padding(.trailing)
            }
        }
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
                            hideKeyboard()
                        case .tvShow(let show):
                            viewModel.selectedTVShow = show
                            viewModel.searchText = show.name
                            hideKeyboard()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if let posterPath = result.posterPath {
                                AsyncImage(url: posterPath.posterURL(size: "w92")) { image in
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
        VStack(spacing: 12) {
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
            // Review textfield
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Review")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.25))
                    
                    if viewModel.reviewText.isEmpty {
                        Text("Write your review here...")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 19))
                            .padding(.top, 16)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $viewModel.reviewText)
                        .foregroundColor(.white)
                        .accentColor(preferredColor)
                        .font(.system(size: 19))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                .frame(height: 150)
            }
            // Watched Date
            HStack(alignment: .center, spacing: 6) {
                Text("Watched on")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                DatePicker(
                    "Watched Date",
                    selection: $viewModel.watchedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accentColor(preferredColor)
                .colorScheme(.dark)
                .labelsHidden()
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                // .background(Color.secondary.opacity(0.25))
                .cornerRadius(16)
                Spacer()
            }
            // Collections
            HStack {
                Text("Collections:")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddCollection = true }) {
                    Text("+ New")
                        .foregroundColor(preferredColor)
                        .font(.subheadline.bold())
                }
            }
            if viewModel.collections.isEmpty {
                Text("No collections added yet")
                .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
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
            if viewModel.selectedMovie != nil || viewModel.selectedTVShow != nil {
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.selectedMovie = nil
                        viewModel.selectedTVShow = nil
                        viewModel.rating = 0
                        viewModel.reviewText = ""
                        viewModel.watchedDate = Date()
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                        viewModel.status = "watched"
                        viewModel.selectedCollections = []
                        hideKeyboard()
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(preferredColor)
                            .cornerRadius(16)
                    }
                    Button(action: {
                        Task {
                            await viewModel.submitReview()
                            if viewModel.success {
                                viewModel.selectedMovie = nil
                                viewModel.selectedTVShow = nil
                                viewModel.rating = 0
                                viewModel.reviewText = ""
                                viewModel.watchedDate = Date()
                                viewModel.searchText = ""
                                viewModel.searchResults = []
                                viewModel.status = "watched"
                                viewModel.selectedCollections = []
                                showSuccess = true
                            }
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(preferredColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .disabled(viewModel.rating == 0 || viewModel.isLoading)
                    .opacity((viewModel.rating == 0 || viewModel.isLoading) ? 0.5 : 1.0)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7).blur(radius: 0.5))
        .cornerRadius(28)
        // .padding(.horizontal, 16)
        .padding(.top, 32)
    }
}

#Preview {
    AddReviewView()
} 
 
 
