import SwiftUI

struct FriendsFeedView: View {
    @State private var navigateToUserSearch = false
    @State private var navigateToFriendRequests = false
    @State private var gradientAngle: Double = 0.0
    @State private var timer: Timer?
    @State private var isLoading = false
    @State private var friends: [UserProfile] = []
    @State private var friendReviews: [Review] = []
    @State private var error: String? = nil
    @State private var selectedFriend: UserProfile? = nil
    @State private var selectedFriendReviews: [Review] = []
    @State private var isLoadingFriendReviews = false
    
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
                                    .font(.title2)
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
                                    .font(.title2.bold())
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
                            
                            // Friends horizontal scroll
                            if !friends.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(friends, id: \.userId) { friend in
                                            FriendChip(
                                                friend: friend,
                                                isSelected: selectedFriend?.userId == friend.userId,
                                                onTap: {
                                                    Task {
                                                        await selectFriend(friend)
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // .cornerRadius(32)
                    // .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
                    .padding(.horizontal)
                    Spacer()
                    
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView("Loading")
                                .tint(.white)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        }
                    } else if let error = error {
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
                        .background(Color(hex: "393B3D").opacity(0.3))
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
                    } else if friendReviews.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "film")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No reviews from friends yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Your friends haven't added any reviews yet. Be the first to share what you're watching!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        // .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(24)
                        .padding(.horizontal)
                    } else {
                        // Selected friend's reviews
                        if let selectedFriend = selectedFriend {
                            FriendReviewsView(
                                friend: selectedFriend,
                                reviews: selectedFriendReviews,
                                isLoading: isLoadingFriendReviews
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
                    Button(action: { navigateToUserSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { 
                            Task { await loadFriendsFeed() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        Button(action: { navigateToFriendRequests = true }) {
                            Image(systemName: "bell")
                        }
                    }
                }
            }
            .background(
                NavigationLink(destination: UserSearchView(), isActive: $navigateToUserSearch) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: FriendRequestsView(), isActive: $navigateToFriendRequests) { EmptyView() }
                    .hidden()
            )
            .task {
                if AuthManager.shared.isAuthenticated {
                    try? await AuthManager.shared.refreshUserProfile()
                }
                await loadFriendsFeed()
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
        isLoading = true
        error = nil
        
        do {
            // Fetch friends list
            let friendsService = FriendsService.shared
            let friendsList = try await friendsService.getFriends()
            
            // Convert Friend objects to UserProfile objects
            friends = friendsList.map { friend in
                UserProfile(
                    userId: friend.user_id,
                    displayName: friend.display_name,
                    email: nil,
                    bio: nil,
                    color: friend.color,
                    createdAt: nil,
                    personalRecommendations: nil,
                    isFriend: true
                )
            }
            
            // Select first friend by default if available
            if let firstFriend = friends.first {
                await selectFriend(firstFriend)
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func selectFriend(_ friend: UserProfile) async {
        selectedFriend = friend
        isLoadingFriendReviews = true
        
        do {
            // Fetch friend's reviews - for now, we'll use the current user's reviews as a placeholder
            // TODO: Implement API endpoint to fetch another user's reviews
            let reviews = try await NetworkService.shared.fetchUserReviews()
            selectedFriendReviews = reviews
        } catch {
            // Handle error silently for now
            selectedFriendReviews = []
        }
        
        isLoadingFriendReviews = false
    }
}

// MARK: - FriendChip Component
struct FriendChip: View {
    let friend: UserProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(friend.displayName ?? "Unknown")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - FriendReviewsView Component
struct FriendReviewsView: View {
    let friend: UserProfile
    let reviews: [Review]
    let isLoading: Bool
    @State private var selectedReview: Review? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Friend name header
            HStack {
                Text("\(friend.displayName ?? "Friend")'s Reviews")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView("Loading reviews...")
                        .tint(.white)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            } else if reviews.isEmpty {
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
                .background(Color(hex: "393B3D").opacity(0.3))
                .cornerRadius(24)
                .padding(.horizontal)
            } else {
                // Group reviews by collection
                let reviewsByCollection = Dictionary(grouping: reviews) { review in
                    review.collections?.first ?? "No Collection"
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(reviewsByCollection.keys.sorted()), id: \.self) { collectionName in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(collectionName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.leading, 16)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 24) {
                                        ForEach(reviewsByCollection[collectionName] ?? [], id: \.self) { review in
                                            GalleryReviewCard(
                                                review: review,
                                                onOpen: { selectedReview = review }
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
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(item: $selectedReview) { review in
            ReviewDetailSheet(review: review)
        }
    }
}

#Preview {
    FriendsFeedView()
} 