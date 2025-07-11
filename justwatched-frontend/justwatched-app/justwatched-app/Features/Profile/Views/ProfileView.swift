import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showEditProfile = false
    @State private var navigateToAddReview = false
    @State private var selectedReview: Review? = nil
    @State private var showWatchlist = false
    @StateObject private var friendVM = ProfileFriendViewModel()
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.fetchProfile()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .resizable()
                            .foregroundColor(.white)
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
            .sheet(item: $selectedReview) { review in
                ReviewDetailSheet(review: review)
            }
            .sheet(isPresented: $showWatchlist) {
                WatchlistView()
            }
            .task {
                await viewModel.fetchProfile()
                if AuthManager.shared.isAuthenticated {
                    try? await AuthManager.shared.refreshUserProfile()
                }
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
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(AuthManager.shared.userProfile?.displayName ?? "UserName")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                Text((AuthManager.shared.userProfile?.bio ?? "")
                        .prefix(80))
                    .font(.footnote)
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
            statView(title: "Groups", value: "0")
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
            default: return .white
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
    
    // --- GALLERY OF REVIEWS ---
    private var reviewsGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.reviews.isEmpty {
                Text("Your Review Gallery")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 16)
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
            }
        }
    }
    
    private var reviewsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Reviews")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 4)
            
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading reviews...")
                        .foregroundColor(Color(hex: "393B3D"))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            } else if let error = viewModel.error {
                VStack(spacing: 8) {
                    Text("Error loading reviews")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                    Button("Retry") {
                        Task {
                            await viewModel.fetchProfile()
                        }
                    }
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            } else if viewModel.reviews.isEmpty {
                Text("No reviews yet.")
                    .foregroundColor(Color(hex: "393B3D"))
                    .padding(.top, 8)
            } else {
                ForEach(viewModel.reviews, id: \.self) { review in
                    ReviewCard(review: review)
                }
            }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 32)
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

// --- Review Detail Sheet ---
struct ReviewDetailSheet: View {
    let review: Review
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
        }
        .padding()
    }
}

struct ReviewCard: View {
    let review: Review
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let posterPath = review.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w92")) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 40, height: 60)
                .cornerRadius(6)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(review.mediaType == "movie" ? "Movie" : "TV Show"): \(review.title)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(review.rating)/5")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                if let content = review.content, !content.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        if content.count > 100 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Text(isExpanded ? "Show less" : "Read more")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                    }
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
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// --- GALLERY REVIEW CARD ---
struct GalleryReviewCard: View {
    let review: Review
    var onOpen: () -> Void
    @State private var showFullReview = false
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("Read more") {
                        showFullReview = true
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
                Button(action: onOpen) {
                    Text("Open")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(16)
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
        .sheet(isPresented: $showFullReview) {
            VStack(spacing: 24) {
                Text("Full Review")
                    .font(.title2.bold())
                ScrollView {
                    Text(review.content ?? "")
                        .font(.body)
                        .padding()
                }
                Button("Close") { showFullReview = false }
                    .font(.headline)
                    .padding()
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// Helper for hex color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AnimatedPaletteGradientBackground: View {
    let paletteName: String
    @State private var gradientAngle: Double = 0.0
    @State private var timer: Timer?

    static func palette(for name: String) -> [Color] {
        let baseColors: [Color]
        switch name {
        case "yellow":
            baseColors = [
                Color(red: 1.0, green: 0.8, blue: 0.2), // gold
                Color(red: 1.0, green: 0.9, blue: 0.4), // yellow
                Color(red: 1.0, green: 1.0, blue: 0.7), // light yellow
                Color(red: 1.0, green: 0.7, blue: 0.2), // orange
                Color(red: 1.0, green: 1.0, blue: 0.5)  // lemon
            ]
        case "green":
            baseColors = [
                Color(red: 0.0, green: 0.4, blue: 0.2), // dark green
                Color(red: 0.1, green: 0.7, blue: 0.3), // green
                Color(red: 0.5, green: 1.0, blue: 0.7), // light green
                Color(red: 0.2, green: 1.0, blue: 0.7), // teal
                Color(red: 0.7, green: 1.0, blue: 0.8)  // mint
            ]
        case "blue":
            baseColors = [
                Color(red: 0.1, green: 0.1, blue: 0.4), // navy
                Color(red: 0.2, green: 0.4, blue: 0.8), // blue
                Color(red: 0.4, green: 0.7, blue: 1.0), // sky blue
                Color(red: 0.2, green: 1.0, blue: 1.0), // cyan
                Color(red: 0.7, green: 0.9, blue: 1.0)  // light blue
            ]
        case "pink":
            baseColors = [
                Color(red: 1.0, green: 0.0, blue: 0.5), // magenta
                Color(red: 1.0, green: 0.4, blue: 0.7), // pink
                Color(red: 1.0, green: 0.7, blue: 0.9), // light pink
                Color(red: 1.0, green: 0.5, blue: 0.7), // rose
                Color(red: 1.0, green: 0.8, blue: 0.7)  // peach
            ]
        default: // "red"
            baseColors = [
                Color(red: 0.4, green: 0.0, blue: 0.0), // dark red
                Color(red: 0.8, green: 0.1, blue: 0.1), // red
                Color(red: 1.0, green: 0.3, blue: 0.2), // orange-red
                Color(red: 1.0, green: 0.5, blue: 0.5), // light red
                Color(red: 1.0, green: 0.4, blue: 0.3)  // coral
            ]
        }
        
        // Make first and last color the same for seamless gradient
        if let firstColor = baseColors.first {
            return baseColors + [firstColor]
        }
        return baseColors
    }

    var body: some View {
        let colors = Self.palette(for: paletteName)
        
        return AngularGradient(
            gradient: Gradient(colors: colors),
            center: .topTrailing,
            startAngle: .degrees(gradientAngle),
            endAngle: .degrees(gradientAngle + 360)
        )
        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
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
        .onChange(of: paletteName) { _ in
            // Reset angle when palette changes for smooth transition
            gradientAngle = 0.0
        }
    }
}

#Preview {
    ProfileView()
}
 
