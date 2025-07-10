import SwiftUI

struct WatchlistButton: View {
    let mediaId: String
    let mediaType: String
    let mediaTitle: String
    let posterPath: String?
    
    @StateObject private var viewModel = WatchlistViewModel()
    @State private var isInWatchlist = false
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            Task {
                await toggleWatchlist()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(isInWatchlist ? "In Watchlist" : "Add to Watchlist")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isInWatchlist 
                    ? Color.green.opacity(0.8) 
                    : Color.blue.opacity(0.8)
            )
            .cornerRadius(20)
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