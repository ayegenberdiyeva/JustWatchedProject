import SwiftUI

struct VotingView: View {
    @ObservedObject var viewModel: RoomDetailViewModel
    let roomId: String
    @Environment(\.dismiss) private var dismiss
    @State private var hasVoted = false
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var showVoteFeedback = false
    @State private var voteFeedback: (type: String, color: Color) = ("", .clear)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if let votingResult = viewModel.votingResult {
                        votingResultSection(votingResult: votingResult)
                    } else if let currentMovie = viewModel.currentMovie {
                        currentMovieSection(movie: currentMovie)
                    } else {
                        waitingSection
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Voting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Close") {
                    //     viewModel.stopVoting()
                    //     dismiss()
                    // }
                    // .foregroundColor(.gray)
                }
            }
            .onAppear {
                // Start voting session if owner
                if viewModel.isOwner {
                    if let jwt = AuthManager.shared.jwt {
                        Task { await viewModel.startVotingSession(roomId: roomId, jwt: jwt) }
                    }
                }
            }
            .onDisappear {
                viewModel.stopVoting()
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    private var waitingSection: some View {
        VStack(spacing: 24) {
            ZStack {
                let colorValue = AuthManager.shared.userProfile?.color ?? "red"
                AnimatedPaletteGradientBackground(paletteName: colorValue)
                    .cornerRadius(32)
                    .overlay(Color.black.opacity(0.5).cornerRadius(32))
                
                VStack(spacing: 16) {
                    Image(systemName: "wand.and.sparkles.inverse")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Not available yet")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Stay tuned!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    // if viewModel.isOwner {
                    //     Button("Start Voting") {
                    //         if let jwt = AuthManager.shared.jwt {
                    //             Task { await viewModel.startVotingSession(roomId: roomId, jwt: jwt) }
                    //         }
                    //     }
                    //     .padding(.horizontal, 24)
                    //     .padding(.vertical, 12)
                    //     .background(preferredColor)
                    //     .foregroundColor(.white)
                    //     .cornerRadius(16)
                    // } else {
                    //     Text("Room owner will start the voting session")
                    //         .font(.subheadline)
                    //         .foregroundColor(.white.opacity(0.7))
                    //         .multilineTextAlignment(.center)
                    // }
                }
                .padding(32)
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(32)
            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
            .padding(.horizontal)
        }
    }
    
    private func currentMovieSection(movie: RoomRecommendation) -> some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 8) {
                Text("Movie \(viewModel.movieIndex + 1) of \(viewModel.totalMovies)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: Double(viewModel.movieIndex + 1), total: Double(viewModel.totalMovies))
                    .progressViewStyle(LinearProgressViewStyle(tint: preferredColor))
                    .scaleEffect(y: 2)
            }
            .padding(.horizontal)
            
            // Swipeable movie card
            ZStack {
                // Background card (shadow effect)
                movieCard(movie: movie)
                    .scaleEffect(0.95)
                    .opacity(0.5)
                    .offset(x: cardOffset.width * 0.1, y: cardOffset.height * 0.1)
                
                // Main card
                movieCard(movie: movie)
                    .offset(cardOffset)
                    .rotationEffect(.degrees(cardRotation))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                cardOffset = value.translation
                                cardRotation = Double(value.translation.width / 20)
                            }
                            .onEnded { value in
                                handleSwipe(value: value, movie: movie)
                            }
                    )
                
                // Vote feedback overlay
                if showVoteFeedback {
                    voteFeedbackOverlay
                }
            }
            
            // Manual vote buttons (fallback)
            if !hasVoted {
                HStack(spacing: 20) {
                    Button(action: {
                        handleVote(movie: movie, vote: "dislike")
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        handleVote(movie: movie, vote: "like")
                    }) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 20)
            } else {
                Text("Vote submitted!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
        }
    }
    
    private func movieCard(movie: RoomRecommendation) -> some View {
        ZStack(alignment: .bottom) {
            if let posterPath = movie.posterPath {
                AsyncImage(url: posterPath.posterURL(size: "w500")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 320, height: 480)
                .clipped()
                .cornerRadius(24)
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 320, height: 480)
            }
            
            // Glass effect overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .frame(height: 200)
                    .frame(width: 320)
            }
            .frame(width: 320, height: 480)
            .allowsHitTesting(false)
            
            // Content overlay
            VStack(alignment: .leading, spacing: 12) {
                Text(movie.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !movie.reasons.isEmpty {
                    Text(movie.reasons.joined(separator: "\n"))
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    Text("Group Score: \(Int(movie.groupScore * 100))%")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    Spacer()
                }
            }
            .padding(20)
            .frame(width: 320)
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
        .frame(width: 320, height: 480)
        .background(Color.white.opacity(0.01))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var voteFeedbackOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(voteFeedback.color.opacity(0.3))
                .frame(width: 320, height: 480)
            
            VStack {
                if voteFeedback.type == "like" {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.red)
                }
                
                Text(voteFeedback.type.uppercased())
                    .font(.title.bold())
                    .foregroundColor(voteFeedback.color)
            }
        }
        .frame(width: 320, height: 480)
        .cornerRadius(24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showVoteFeedback = false
                }
            }
        }
    }
    
    private func handleSwipe(value: DragGesture.Value, movie: RoomRecommendation) {
        let threshold: CGFloat = 100
        let swipeDistance = abs(value.translation.width)
        
        if swipeDistance > threshold {
            let vote = value.translation.width > 0 ? "like" : "dislike"
            handleVote(movie: movie, vote: vote)
            
            // Animate card off screen
            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = CGSize(
                    width: value.translation.width > 0 ? 500 : -500,
                    height: value.translation.height
                )
                cardRotation = value.translation.width > 0 ? 20 : -20
            }
        } else {
            // Reset card position
            withAnimation(.spring()) {
                cardOffset = .zero
                cardRotation = 0
            }
        }
    }
    
    private func handleVote(movie: RoomRecommendation, vote: String) {
        guard !hasVoted else { return }
        
        // Send vote to backend
        viewModel.sendVote(movieId: movie.movieId, vote: vote)
        hasVoted = true
        
        // Show feedback
        voteFeedback = (
            type: vote,
            color: vote == "like" ? .green : .red
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showVoteFeedback = true
        }
        
        // Reset card position for next movie
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring()) {
                cardOffset = .zero
                cardRotation = 0
            }
            hasVoted = false
        }
    }
    
    private func votingResultSection(votingResult: WebSocketVotingResultMessage) -> some View {
        VStack(spacing: 24) {
            ZStack {
                let colorValue = AuthManager.shared.userProfile?.color ?? "red"
                AnimatedPaletteGradientBackground(paletteName: colorValue)
                    .cornerRadius(32)
                    .overlay(Color.black.opacity(0.5).cornerRadius(32))
                
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Voting Complete!")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("The group has chosen a movie")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(32)
            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
            .padding(.horizontal)
            
            // Winner card
            ZStack(alignment: .bottom) {
                if let posterPath = votingResult.winner.posterPath {
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
                
                // Glass effect overlay
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .frame(height: 200)
                        .frame(width: 300)
                }
                .frame(width: 300, height: 450)
                .allowsHitTesting(false)
                
                // Content overlay
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("WINNER")
                            .font(.headline.bold())
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    
                    Text(votingResult.winner.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("Final Score: \(Int(votingResult.score * 100))%")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        Spacer()
                    }
                    
                    Text("\(votingResult.totalParticipants) participants voted")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
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
        }
    }
    
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
}

#Preview {
    VotingView(viewModel: RoomDetailViewModel(), roomId: "test-room-id")
} 