import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showEditProfile = false
    @State private var navigateToAddReview = false
    @State private var selectedReview: Review? = nil
    @State private var showWatchlist = false
    @State private var navigateToSettings = false
    @StateObject private var friendVM = ProfileFriendViewModel()
    @State private var collectionsData: CollectionsResponse? = nil
    @State private var isLoadingCollections = false
    @State private var showFriendsList = false
    // Replace with the actual userId being viewed (for now, use AuthManager.shared.userProfile?.id for own profile)
    var viewedUserId: String? { viewModel.userProfile?.id }
    var isOwnProfile: Bool { viewedUserId == AuthManager.shared.userProfile?.id }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                        if let userId = viewedUserId, !isOwnProfile {
                            friendActionButtons(userId: userId)
                        }
                        statsCard
                        actionButtons
                        reviewsGallery
                        collectionsSection
                        // reviewsList
                        logoutButton
                        NavigationLink(destination: AddReviewView(onReviewAdded: {
                            Task { await viewModel.fetchProfile() }
                        }), isActive: $navigateToAddReview) {
                            EmptyView()
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigateToSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Button(action: {
                            Task {
                                await fetchAllData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile, onDismiss: {
                Task {
                    await viewModel.fetchProfile()
                }
            }) {
                EditProfileView(viewModel: EditProfileViewModel(profileViewModel: viewModel))
            }

            .navigationDestination(isPresented: $showWatchlist) {
                WatchlistView()
            }
            .navigationDestination(isPresented: $showFriendsList) {
                FriendsListView()
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedReview) { review in
                ReviewDetailSheet(review: review, onReviewDeleted: {
                    Task {
                        await fetchAllData()
                    }
                })
            }
            .task {
                await fetchAllData()
            }
        }
    }
    
    private var profileHeader: some View {
        ZStack {
            let colorValue = AuthManager.shared.userProfile?.color ?? "red"
            AnimatedPaletteGradientBackground(paletteName: colorValue)
                .cornerRadius(32)
                .overlay(Color.black.opacity(0.5).cornerRadius(32))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Hi, ")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    Text(AuthManager.shared.userProfile?.displayName ?? "UserName")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text((AuthManager.shared.userProfile?.bio ?? "")
                        .prefix(80))
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private var statsCard: some View {
        HStack(spacing: 0) {
            statView(title: "Reviews", value: "\(viewModel.reviews.count)")
            Divider().frame(height: 40).background(Color(hex: "393B3D"))
            clickableWatchlistStatView
            Divider().frame(height: 40).background(Color(hex: "393B3D"))
            clickableFriendsStatView
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        let preferredColor: Color = {
            switch AuthManager.shared.userProfile?.color {
            case "red": return .red
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "pink": return .pink
            default: return .red
            }
        }()
        return HStack(spacing: 12) {
            Button(action: { showEditProfile = true }) {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }
            Button(action: { navigateToAddReview = true }) {
                Label("Add Review", systemImage: "plus")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(preferredColor)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    private var logoutButton: some View {
            Button(action: { AuthManager.shared.signOut() }) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
    
    private var clickableWatchlistStatView: some View {
        Button(action: { showWatchlist = true }) {
            VStack {
                Text("\(viewModel.watchlistCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Watchlist")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "393B3D"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var clickableFriendsStatView: some View {
        Button(action: { showFriendsList = true }) {
            VStack {
                Text("\(viewModel.friendsCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Friends")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "393B3D"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // --- GALLERY OF REVIEWS ---
    private var reviewsGallery: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Your Review Gallery")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            if !viewModel.reviews.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(viewModel.reviews, id: \.self) { review in
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
            } else {
                Text("No reviews yet.")
                    .foregroundColor(Color(hex: "393B3D"))
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    // --- COLLECTIONS SECTION ---
    private var collectionsSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Your Collections")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            if isLoadingCollections {
                HStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let collections = collectionsData?.collections, !collections.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(collections, id: \.collectionId) { collection in
                            VStack(alignment: .leading, spacing: 12) {
                                // Collection header with review count
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
                                
                                // Horizontal scroll of reviews in this collection
                                if !collection.reviews.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 24) {
                                            ForEach(collection.reviews, id: \.self) { userReview in
                                                GalleryReviewCard(
                                                    review: convertToReview(userReview),
                                                    onOpen: { selectedReview = convertToReview(userReview) }
                                                )
                                                .scrollTargetLayout()
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                } else {
                                    Text("No reviews in this collection yet")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 16)
                }
                .scrollTargetBehavior(.viewAligned)
            } else {
                Text("No collections yet.")
                    .foregroundColor(Color(hex: "393B3D"))
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private func fetchAllData() async {
        await withTaskGroup(of: Void.self) { group in
            // Add task for fetching profile data (includes reviews)
            group.addTask {
                await viewModel.fetchProfile()
            }
            
            // Add task for fetching collections
            group.addTask {
                await fetchCollections()
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
        
        // Refresh user profile after all data is fetched
        if AuthManager.shared.isAuthenticated {
            try? await AuthManager.shared.refreshUserProfile()
        }
    }
    
    private func fetchCollections() async {
        isLoadingCollections = true
        
        do {
            let response = try await NetworkService.shared.fetchUserCollectionsWithReviews()
            await MainActor.run {
                collectionsData = response
            }
        } catch {
            // Handle error silently or log to a proper logging system
        }
        
        isLoadingCollections = false
    }
    
    // Convert UserCollectionReview to Review for GalleryReviewCard compatibility
    private func convertToReview(_ userReview: UserCollectionReview) -> Review {
        return Review(
            reviewId: userReview.reviewId,
            mediaId: userReview.mediaId,
            mediaType: userReview.mediaType,
            rating: userReview.rating ?? 0,
            content: userReview.reviewText,
            posterPath: userReview.posterPath,
            watchedDate: userReview.watchedDate != nil ? ISO8601DateFormatter().date(from: userReview.watchedDate!) : nil,
            title: userReview.mediaTitle,
            status: userReview.status,
            createdAt: ISO8601DateFormatter().date(from: userReview.createdAt),
            updatedAt: ISO8601DateFormatter().date(from: userReview.updatedAt)
        )
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "393B3D"))
        }
        .frame(maxWidth: .infinity)
    }
    
    // --- FRIEND ACTION BUTTONS ---
    @ViewBuilder
    private func friendActionButtons(userId: String) -> some View {
        VStack(spacing: 8) {
            if let error = friendVM.error {
                Text(error).foregroundColor(.red)
            }
            if friendVM.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else {
                switch friendVM.friendStatus {
                case "not_friends":
                    Button("Add Friend") {
                        Task { await friendVM.sendRequest(to: userId) }
                    }
                    .buttonStyle(.borderedProminent)
                case "pending_sent":
                    Button("Friend Request Sent") {}
                        .disabled(true)
                        .buttonStyle(.bordered)
                case "pending_received":
                    HStack {
                        Button("Accept") {
                            if let reqId = friendVM.pendingRequestId {
                                Task { await friendVM.respondToRequest(requestId: reqId, action: "accept") }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Decline") {
                            if let reqId = friendVM.pendingRequestId {
                                Task { await friendVM.respondToRequest(requestId: reqId, action: "decline") }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                case "friends":
                    Button("Remove Friend") {
                        Task { await friendVM.removeFriend(userId: userId) }
                    }
                    .buttonStyle(.bordered)
                default:
                    EmptyView()
                }
            }
        }
        .onAppear {
            Task { await friendVM.checkStatus(with: userId) }
        }
        .padding(.horizontal)
    }
}











#Preview {
    ProfileView()
}
 
