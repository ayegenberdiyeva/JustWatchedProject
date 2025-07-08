import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if !authManager.isAuthenticated {
                    Text("Please log in to see recommendations")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.isLoading {
                    ProgressView("Loading recommendations...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    if let taste = viewModel.tasteProfile {
                        Text("Taste Profile: \(taste)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Last updated: \(lastUpdated)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    List(viewModel.recommendations) { rec in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rec.title)
                                .font(.headline)
                            if let reason = rec.reason {
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Home")
            .onAppear {
                if authManager.isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRecommendations(jwt: jwt) }
                }
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRecommendations(jwt: jwt) }
                }
            }
        }
    }
}

#Preview {
    HomeView()
} 