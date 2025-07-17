import SwiftUI

struct FriendsFeedView: View {
    @State private var navigateToUserSearch = false
    @State private var navigateToFriendRequests = false
    @State private var gradientAngle: Double = 0.0
    @State private var timer: Timer?
    @State private var isLoading = false
    @State private var friends: [UserProfile] = []
    @State private var error: String? = nil
    @State private var selectedFriend: UserProfile? = nil
    @State private var friendsReviewsData: FriendsReviewsResponse? = nil
    @State private var isLoadingFriendReviews = false
    @State private var incomingRequestsCount = 0
    @State private var selectedReview: Review? = nil
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack () {
                    let colorValue = AuthManager.shared.userProfile?.color ?? "red"
                    ZStack {
                        // AnimatedPaletteGradientBackground(paletteName: colorValue)
                        //     .cornerRadius(32)
                        //     .overlay(Color.black.opacity(0.5).cornerRadius(32))
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("Watched by ")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(
                                        AngularGradient(
                                            gradient: Gradient(colors: AnimatedPaletteGradientBackground.palette(for: colorValue)),
                                            center: .topTrailing,
                                            startAngle: .degrees(gradientAngle),
                                            endAngle: .degrees(gradientAngle + 360)
                                        )
                                    )
                                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
                                Text("Friends")
                                    .font(.system(size: 32, weight: .heavy))
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
                            
                            // Friends horizontal scroll with search button
                            HStack(spacing: 12) {
                                Button(action: { navigateToUserSearch = true }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(Color.white)
                                        .font(.title3)
                                        .frame(width: 32, height: 32)
                                        // .background(Color.white.opacity(0.1))
                                        // .clipShape(Circle())
                                }
                                
                                if !friends.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(friends, id: \.userId) { friend in
                                                Button(action: {
                                                    selectFriend(friend)
                                                }) {
                                                    HStack {
                                                        Text(friend.displayName ?? "Unknown")
                                                            .foregroundColor(.white)
                                                            .fontWeight(.medium)
                                                    }
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 14)
                                                    .background(selectedFriend?.userId == friend.userId ? preferredColor.opacity(0.18) : Color.clear)
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
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // .cornerRadius(32)
                    // .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
                    .padding(.horizontal)
                    Spacer()
                    
                    if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Error loading friends' reviews")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await loadFriendsFeed() }
                            }
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding()
//                        .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(24)
                        .padding(.horizontal)
                    } else if friends.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No friends yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Add some friends to see what they're watching!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Button("Find Friends") {
                                navigateToUserSearch = true
                            }
                            .padding()
                            .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding()
                        // .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(24)
                        .padding(.horizontal)
                    } else {
                        // Selected friend's reviews
                        if let selectedFriend = selectedFriend,
                           let friendsData = friendsReviewsData,
                           let friendData = friendsData.friends.first(where: { $0.userId == selectedFriend.userId }) {
                            FriendReviewsView(
                                friend: selectedFriend,
                                friendData: friendData,
                                isLoading: isLoadingFriendReviews,
                                onRefresh: loadFriendsFeed,
                                selectedReview: $selectedReview
                            )
                        } else {
                            // Default view when no friend is selected
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Select a friend to see their reviews")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.leading, 16)
                                
                                Text("Tap on a friend's name above to view their movie reviews")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { navigateToFriendRequests = true }) {
                        ZStack {
                            Image(systemName: "bell")
                                .foregroundColor(.white)
                            if incomingRequestsCount > 0 {
                                Text("\(incomingRequestsCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(4)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Button(action: { 
                            Task { 
                                await loadFriendsFeed()
                                await loadPendingFriendRequests()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .background(
                NavigationLink(destination: UserSearchView(), isActive: $navigateToUserSearch) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: FriendsListView(), isActive: $navigateToFriendRequests) { EmptyView() }
                    .hidden()
            )
            .navigationDestination(item: $selectedReview) { review in
                ReviewDetailSheet(review: review, onReviewDeleted: {
                    Task { await loadFriendsFeed() }
                })
            }
            .task {
                if AuthManager.shared.isAuthenticated {
                    try? await AuthManager.shared.refreshUserProfile()
                }
                await loadFriendsFeed()
                await loadIncomingRequestsCount()
            }
            .onAppear {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    gradientAngle += 1.0
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func loadFriendsFeed() async {
        // First, try to load from cache
        if let cachedFriendsReviews = CacheManager.shared.getCachedFriendsReviews() {
            friendsReviewsData = cachedFriendsReviews
            
            // Convert to UserProfile objects for the friends list
            friends = cachedFriendsReviews.friends.map { friendData in
                UserProfile(
                    userId: friendData.userId,
                    displayName: friendData.displayName,
                    email: nil,
                    bio: nil,
                    color: friendData.color,
                    createdAt: nil,
                    personalRecommendations: nil,
                    isFriend: true
                )
            }
            
            // Select first friend by default if available
            if let firstFriend = friends.first {
                selectedFriend = firstFriend
            }
        }
        
        isLoading = true
        error = nil
        
        do {
            // Fetch friends reviews by collections
            let friendsReviewsResponse = try await NetworkService.shared.fetchFriendsReviews()
            friendsReviewsData = friendsReviewsResponse
            
            // Convert to UserProfile objects for the friends list
            friends = friendsReviewsResponse.friends.map { friendData in
                UserProfile(
                    userId: friendData.userId,
                    displayName: friendData.displayName,
                    email: nil,
                    bio: nil,
                    color: friendData.color,
                    createdAt: nil,
                    personalRecommendations: nil,
                    isFriend: true
                )
            }
            
            // Select first friend by default if available
            if let firstFriend = friends.first {
                selectedFriend = firstFriend
            }
            
            // Cache the friends reviews
            CacheManager.shared.cacheFriendsReviews(friendsReviewsResponse)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func selectFriend(_ friend: UserProfile) {
        selectedFriend = friend
    }
    
    private func loadIncomingRequestsCount() async {
        await loadPendingFriendRequests()
    }
    
    private func loadPendingFriendRequests() async {
        do {
            let pendingRequests = try await FriendsService.shared.getPendingRequests()
            let incomingRequests = pendingRequests.filter { $0.status == "pending_received" }
            await MainActor.run {
                incomingRequestsCount = incomingRequests.count
            }
        } catch {
            // Check if this is a cancellation error and ignore it
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Request was cancelled, this is normal when view disappears or multiple requests are made
                return
            }
            print("Error loading pending friend requests: \(error)")
        }
    }
}



// MARK: - FriendReviewsView Component
struct FriendReviewsView: View {
    let friend: UserProfile
    let friendData: FriendReviewsData
    let isLoading: Bool
    let onRefresh: () async -> Void
    @Binding var selectedReview: Review?
    @State private var showAddReview = false
    @State private var selectedReviewForAdd: Review? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if friendData.collections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No reviews yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(friend.displayName ?? "This friend") hasn't added any reviews yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                // .background(Color(hex: "393B3D").opacity(0.3))
                .cornerRadius(24)
                .padding(.horizontal)
            } else {
                // Display collections with their reviews
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(friendData.collections) { collection in
                            VStack(alignment: .leading, spacing: 12) {
                                // Collection header with review count - this is the scroll target
                                HStack {
                                    Text(collection.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("(\(collection.reviewCount))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.leading, 16)
                                .scrollTargetLayout()
                                
                                // Horizontal scroll of reviews in this collection
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 24) {
                                        ForEach(collection.reviews, id: \.self) { review in
                                            FriendReviewCard(
                                                review: review,
                                                onOpen: { selectedReview = review },
                                                onAddReview: {
                                                    selectedReviewForAdd = review
                                                    showAddReview = true
                                                }
                                            )
                                            .scrollTargetLayout()
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .scrollTargetBehavior(.viewAligned)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 16)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .sheet(isPresented: $showAddReview) {
            if let review = selectedReviewForAdd {
                AddReviewView(
                    selectedMovie: review.mediaType == "movie" ? createMovieFromReview(review) : nil,
                    selectedTVShow: review.mediaType == "tv" ? createTVShowFromReview(review) : nil,
                    onReviewAdded: {
                        // Refresh the friends feed after adding a review
                        Task { await onRefresh() }
                    }
                )
            }
        }
    }
    
    private func createMovieFromReview(_ review: Review) -> Movie {
        let movieId = Int(review.mediaId) ?? 0
        let movieTitle = review.title
        let moviePosterPath = review.posterPath
        let movieOverview = review.content ?? ""
        
        return Movie(
            id: movieId,
            title: movieTitle,
            posterPath: moviePosterPath,
            releaseDate: review.watchedDate?.formatted(date: .abbreviated, time: .omitted),
            overview: movieOverview
        )
    }
    
    private func createTVShowFromReview(_ review: Review) -> TVShow {
        let showId = Int(review.mediaId) ?? 0
        let showName = review.title
        let showPosterPath = review.posterPath
        let showOverview = review.content ?? ""
        
        return TVShow(
            id: showId,
            name: showName,
            posterPath: showPosterPath,
            firstAirDate: review.watchedDate?.formatted(date: .abbreviated, time: .omitted),
            overview: showOverview
        )
    }
}

// MARK: - FriendReviewCard Component
struct FriendReviewCard: View {
    let review: Review
    let onOpen: () -> Void
    let onAddReview: () -> Void
    
    private let preferredColor: Color = {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }()

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
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("Read more") {
                        onOpen()
                    }
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: "393B3D"))
                    .padding(.top, 0)
                    .padding(.bottom, 2)
                } else {
                    Text("")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                        .lineLimit(1)
                    // Placeholder for alignment
                    Text("Read more")
                        .font(.caption.bold())
                        .foregroundColor(Color.clear)
                        .padding(.top, 0)
                        .padding(.bottom, 2)
                }
                HStack(spacing: 6) {
                    // VStack {
                        // Text("Watched on")
                        //     .font(.caption)
                        //     .foregroundColor(.white.opacity(0.8))
                    //     Text(review.watchedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                    //         .font(.title3.bold())
                    //         .foregroundColor(.white)
                    // }
                    // .frame(maxWidth: .infinity)
                    // .padding(8)
                    // .background(Color.black.opacity(0.3))
                    // .cornerRadius(12)
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
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                HStack(spacing: 6) {
                    Button(action: onAddReview) {
                        VStack {
                            Text("Review")
                                .font(.caption)
                                .foregroundColor(preferredColor)
                            Image(systemName: "star.fill")
                                .font(.title3.bold())
                                .foregroundColor(preferredColor)
                                .frame(height: 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                    
                    WatchlistButton(
                        mediaId: review.mediaId,
                        mediaType: review.mediaType,
                        mediaTitle: review.title,
                        posterPath: review.posterPath
                    )
                    .frame(maxWidth: .infinity)
                }
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
            onOpen()
        }
    }
}

#Preview {
    FriendsFeedView()
} 
