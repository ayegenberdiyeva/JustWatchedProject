import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recommendations: [RecommendationResult] = []
    @Published var tasteProfile: String? = nil
    @Published var lastUpdated: String? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    func fetchRecommendations(jwt: String) async {
        isLoading = true
        error = nil
        guard let url = URL(string: "http://localhost:8000/api/v1/users/me/recommendations") else { 
            error = "Invalid URL"
            isLoading = false
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    error = "No recommendations yet, please check back later."
                    recommendations = []
                    tasteProfile = nil
                    lastUpdated = nil
                    isLoading = false
                    return
                }
                
                // Debug: Print raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
            }
            
            // Try to decode
            let recs = try JSONDecoder().decode(UserRecommendationsResponse.self, from: data)
            recommendations = recs.recommendations
            tasteProfile = recs.taste_profile
            lastUpdated = recs.last_updated
            
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            switch decodingError {
            case .dataCorrupted(let context):
                error = "Data corrupted: \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                error = "Missing key '\(key.stringValue)': \(context.debugDescription)"
            case .typeMismatch(let type, let context):
                error = "Type mismatch for \(type): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                error = "Value not found for \(type): \(context.debugDescription)"
            @unknown default:
                error = "Unknown decoding error: \(decodingError.localizedDescription)"
            }
        } catch {
            print("Network error: \(error)")
            self.error = "Network error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 