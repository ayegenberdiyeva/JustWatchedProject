import SwiftUI

struct WatchlistButton: View {
    let mediaId: String
    let mediaType: String
    let mediaTitle: String
    let posterPath: String?
    
    @StateObject private var viewModel = WatchlistViewModel()
    @State private var isInWatchlist = false
    @State private var isLoading = false
    
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
    
    var body: some View {
        Button(action: {
            Task {
                await toggleWatchlist()
            }
        }) {
            VStack {
                Text(isLoading ? "Loading..." : (isInWatchlist ? "In Watchlist" : "Watchlist"))
                    .font(.caption)
                    .foregroundColor(isInWatchlist ? .white : preferredColor)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(isInWatchlist ? .white : preferredColor)
                        .frame(height: 20)
                } else {
                    Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title3.bold())
                        .foregroundColor(isInWatchlist ? .white : preferredColor)
                        .frame(height: 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(isInWatchlist ? preferredColor : Color.black.opacity(0.3))
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .task {
            await checkWatchlistStatus()
        }
    }
    
    private func checkWatchlistStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        isInWatchlist = await viewModel.checkWatchlistStatus(mediaId: mediaId)
    }
    
    private func toggleWatchlist() async {
        isLoading = true
        defer { isLoading = false }
        
        if isInWatchlist {
            await viewModel.removeFromWatchlist(mediaId: mediaId)
            isInWatchlist = false
        } else {
            await viewModel.addToWatchlist(
                mediaId: mediaId,
                mediaType: mediaType,
                mediaTitle: mediaTitle,
                posterPath: posterPath
            )
            isInWatchlist = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WatchlistButton(
            mediaId: "123",
            mediaType: "movie",
            mediaTitle: "Inception",
            posterPath: "/poster.jpg"
        )
    }
} 