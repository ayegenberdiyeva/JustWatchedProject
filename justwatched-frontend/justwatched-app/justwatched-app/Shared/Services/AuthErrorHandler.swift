import Foundation

// MARK: - Centralized Authentication Error Handler
actor AuthErrorHandler {
    static let shared = AuthErrorHandler()
    
    private init() {}
    
    func handleAuthenticationError(_ response: URLResponse) async {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            print("🔐 Authentication error detected: \(httpResponse.statusCode)")
            await MainActor.run {
                AuthManager.shared.signOut()
            }
        }
    }
    
    func handleResponse<T>(_ response: URLResponse, data: Data, decoder: JSONDecoder = JSONDecoder()) async throws -> T where T: Decodable {
        // Handle authentication errors first
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    func handleEmptyResponse(_ response: URLResponse) async throws {
        // Handle authentication errors first
        await handleAuthenticationError(response)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
} 