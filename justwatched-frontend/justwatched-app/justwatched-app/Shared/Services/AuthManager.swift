import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {
        // Load saved JWT if exists
        if let savedJWT = UserDefaults.standard.string(forKey: jwtKey) {
            self.jwt = savedJWT
        }
    }

    // MARK: - Storage Keys
    private let jwtKey = "auth_jwt_token"

    // MARK: - Published State
    @Published var jwt: String? {
        didSet { saveJWT(jwt) }
    }
    @Published var userProfile: UserProfile?

    // MARK: - Auth State
    var isAuthenticated: Bool {
        guard let jwt = jwt, !jwt.isEmpty else { return false }
        return !isJWTExpired(jwt)
    }

    // MARK: - JWT Storage (UserDefaults for now)
    private func saveJWT(_ token: String?) {
        if let token = token {
            UserDefaults.standard.set(token, forKey: jwtKey)
            // TODO: In production, store in Keychain instead of UserDefaults for security.
        } else {
            UserDefaults.standard.removeObject(forKey: jwtKey)
        }
    }
    private func loadJWT() -> String? {
        // TODO: In production, load from Keychain.
        return UserDefaults.standard.string(forKey: jwtKey)
    }

    // MARK: - User Profile Management (No Caching)

    // MARK: - JWT Expiration
    private func isJWTExpired(_ jwt: String) -> Bool {
        guard let payload = decodeJWTPayload(jwt),
              let exp = payload["exp"] as? TimeInterval else { return true }
        let expirationDate = Date(timeIntervalSince1970: exp)
        return Date() >= expirationDate
    }
    private func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".")
        guard segments.count == 3 else { return nil }
        let payloadSegment = segments[1]
        var base64 = String(payloadSegment)
        // Pad base64 if needed
        let requiredLength = 4 * ((base64.count + 3) / 4)
        base64 = base64.padding(toLength: requiredLength, withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: - Public API
    func loadFromStorage() {
        self.jwt = loadJWT()
    }

    func login(email: String, password: String) async throws {
        let network = NetworkService.shared
        let auth = try await network.login(email: email, password: password)
        await MainActor.run { self.jwt = auth.access_token }
        // Try to get existing profile, create one if it doesn't exist
        do {
            try await refreshUserProfile()
        } catch {
            // If profile doesn't exist, create one
            if let networkError = error as? NetworkError,
               case .requestFailed(let statusCode) = networkError,
               statusCode == 404 {
                // Profile doesn't exist, create one
                // Extract user_id from JWT
                if let payload = decodeJWTPayload(auth.access_token),
                   let userId = payload["sub"] as? String {
                    let profile = try await network.createUserProfile(
                        jwt: auth.access_token,
                        userId: userId,
                        displayName: "",
                        email: email,
                        bio: "No bio yet"
                    )
                    await MainActor.run { self.userProfile = profile }
                } else {
                    throw AuthError.profileNotFound
                }
            } else {
                // Re-throw other errors
                throw error
            }
        }
    }

    func register(email: String, password: String, displayName: String = "") async throws {
        let network = NetworkService.shared
        let auth = try await network.register(email: email, password: password)
        await MainActor.run { self.jwt = auth.access_token }
        
        print("🔍 Registration successful, creating user profile...")
        
        // Use PATCH /api/v1/users/me since POST /api/v1/users fails due to backend architecture
        let profile = try await network.updateUserProfile(
            jwt: auth.access_token,
            displayName: displayName.isEmpty ? email : displayName,
            email: email,
            bio: "No bio yet",
            color: "red"
        )
        await MainActor.run { self.userProfile = profile }
        print("✅ User profile created successfully")
        
        // Fetch the profile to ensure it's properly loaded
        try await refreshUserProfile()
        print("✅ Profile fetched and loaded")
    }

    // func logout() {
    //     self.jwt = nil
    //     self.userProfile = nil
    // }

    func refreshUserProfile() async throws {
        guard let jwt = jwt else { throw AuthError.notAuthenticated }
        let network = NetworkService.shared
        let profile = try await network.getCurrentUserProfile(jwt: jwt)
        await MainActor.run { self.userProfile = profile }
    }

    func updateCurrentUserProfile(displayName: String, email: String, bio: String?) async throws {
        guard let jwt = jwt else { throw AuthError.notAuthenticated }
        let network = NetworkService.shared
        _ = try await network.updateCurrentUserProfile(
            jwt: jwt,
            displayName: displayName,
            email: email,
            bio: bio ?? "No bio yet"
        )
        try await refreshUserProfile()
    }

    func signIn(withJWT jwt: String) {
        Task { @MainActor in
            self.jwt = jwt
            UserDefaults.standard.set(jwt, forKey: jwtKey)
        }
    }
    
    func signOut() {
        Task { @MainActor in
            self.jwt = nil
            self.userProfile = nil
            UserDefaults.standard.removeObject(forKey: jwtKey)
        }
    }
    
    func deleteAccount() async throws -> AccountDeletionResponse {
        guard let jwt = jwt else { throw AuthError.notAuthenticated }
        
        let network = NetworkService.shared
        let response = try await network.deleteAccount()
        
        // Clear local data after successful deletion
        await MainActor.run {
            self.jwt = nil
            self.userProfile = nil
            UserDefaults.standard.removeObject(forKey: jwtKey)
        }
        
        return response
    }

    enum AuthError: LocalizedError {
        case notAuthenticated
        case invalidCredentials
        case profileNotFound
        case networkError(String)
        case accountDeletionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "User is not authenticated."
            case .invalidCredentials: return "Invalid email or password."
            case .profileNotFound: return "User profile not found."
            case .networkError(let message): return "Network error: \(message)"
            case .accountDeletionFailed(let message): return "Account deletion failed: \(message)"
            }
        }
    }
} 