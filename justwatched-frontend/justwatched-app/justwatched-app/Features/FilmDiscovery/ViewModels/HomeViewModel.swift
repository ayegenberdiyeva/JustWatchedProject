import Foundation
import SwiftUI

struct Recommendation: Codable, Identifiable {
    let id: String
    let title: String
    let justification: String?
}

struct RecommendationResponse: Codable {
    let recommendations: [Recommendation]
    let taste_profile: String?
    let last_updated: String?
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    @Published var tasteProfile: String? = nil
    @Published var lastUpdated: String? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    func fetchRecommendations(jwt: String) async {
        isLoading = true
        error = nil
        guard let url = URL(string: "http://localhost:8000/api/v1/users/me/recommendations") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                error = "No recommendations yet, please check back later."
                recommendations = []
                tasteProfile = nil
                lastUpdated = nil
            } else {
                let recs = try JSONDecoder().decode(RecommendationResponse.self, from: data)
                recommendations = recs.recommendations
                tasteProfile = recs.taste_profile
                lastUpdated = recs.last_updated
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 