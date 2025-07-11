import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var navigateToAddReview = false
    @State private var selectedRecommendation: RecommendationResult? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !authManager.isAuthenticated {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Please log in to see recommendations")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerSection
                                .frame(height: 150)
                            if viewModel.isLoading {
                                ProgressView("Loading recommendations...")
                                    .tint(.white)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 40)
                            } else if let error = viewModel.error {
                                errorSection(error: error)
                            } else if viewModel.recommendations.isEmpty {
                                emptyStateSection
                            } else {
                                recommendationsGallery
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.isAuthenticated, let jwt = authManager.jwt {
                            Task { await viewModel.fetchRecommendations(jwt: jwt) }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                if authManager.isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRecommendations(jwt: jwt) }
                }
            }
            .task {
                if AuthManager.shared.isAuthenticated {
                    try? await AuthManager.shared.refreshUserProfile()
                }
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRecommendations(jwt: jwt) }
                }
            }
        }
    }
    
    private var headerSection: some View {
        let colorValue = AuthManager.shared.userProfile?.color ?? "red"
        return ZStack {
            AnimatedPaletteGradientBackground(paletteName: colorValue)
                .cornerRadius(32)
                .overlay(Color.black.opacity(0.5).cornerRadius(32))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Recommended ")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("For You")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                if let generatedAt = viewModel.generatedAt {
                    Text("Generated: \(formatDate(generatedAt))")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
                Text("Personalized recommendations based on your taste")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private func errorSection(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Error loading recommendations")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Retry") {
                if authManager.isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRecommendations(jwt: jwt) }
                }
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
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No recommendations yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Add some reviews to help us understand your taste!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private var recommendationsGallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Personalized Picks")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(viewModel.recommendations) { recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            onAddReview: {
                                selectedRecommendation = recommendation
                                navigateToAddReview = true
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct RecommendationCard: View {
    let recommendation: RecommendationResult
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
            // Poster Background
            if let posterPath = recommendation.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w500")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 300, height: 450)
                .clipped()
                .cornerRadius(24)
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 300, height: 450)
            }
            
            // Glass Effect Overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .frame(height: 240)
                    .frame(width: 300)
            }
            .frame(width: 300, height: 450)
            .allowsHitTesting(false)
            
            // Content Overlay
            VStack(alignment: .leading, spacing: 12) {
                Text(recommendation.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                
                if let reasoning = recommendation.reasoning {
                    Text(reasoning)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                if let score = recommendation.confidenceScore {
                    HStack {
                        Text("Match: \(Int(score * 100))%")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        Spacer()
                    }
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
                        mediaId: recommendation.movieId,
                        mediaType: recommendation.mediaType,
                        mediaTitle: recommendation.title,
                        posterPath: recommendation.posterPath
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(width: 300)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.4),
                        Color.clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .cornerRadius(24)
            )
        }
        .frame(width: 300, height: 450)
        .background(Color.white.opacity(0.01))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.vertical, 8)
    }
}



#Preview {
    HomeView()
} 
