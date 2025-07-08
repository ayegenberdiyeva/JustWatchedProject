import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var jwt: String = AuthManager.shared.jwt ?? ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
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
                            if let justification = rec.justification {
                                Text(justification)
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
                Task { await viewModel.fetchRecommendations(jwt: jwt) }
            }
        }
    }
}

#Preview {
    HomeView()
} 