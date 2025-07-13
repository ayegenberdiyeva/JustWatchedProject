import SwiftUI

struct VotingView: View {
    @ObservedObject var viewModel: RoomDetailViewModel
    let roomId: String
    @Environment(\.dismiss) private var dismiss
    @State private var hasVoted = false
    
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
                    Button("Close") {
                        viewModel.stopVoting()
                        dismiss()
                    }
                    .foregroundColor(.gray)
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
                    Image(systemName: "hand.raised")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Waiting for voting to start...")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if viewModel.isOwner {
                        Button("Start Voting") {
                            if let jwt = AuthManager.shared.jwt {
                                Task { await viewModel.startVotingSession(roomId: roomId, jwt: jwt) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(preferredColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    } else {
                        Text("Room owner will start the voting session")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
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
            
            // Movie card
            ZStack(alignment: .bottom) {
                if let posterPath = movie.posterPath {
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
                    
                    // Voting buttons
                    if !hasVoted {
                        HStack(spacing: 16) {
                            Button(action: {
                                viewModel.sendVote(movieId: movie.movieId, vote: "like")
                                hasVoted = true
                            }) {
                                VStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.title2)
                                    Text("Like")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                viewModel.sendVote(movieId: movie.movieId, vote: "dislike")
                                hasVoted = true
                            }) {
                                VStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.title2)
                                    Text("Dislike")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                        }
                    } else {
                        Text("Vote submitted!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
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