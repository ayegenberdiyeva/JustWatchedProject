import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {
        // Load saved tokens if they exist
        loadTokensFromStorage()
    }

    // MARK: - Storage Keys
    private let accessTokenKey = "auth_access_token"
    private let refreshTokenKey = "auth_refresh_token"
    private let tokenExpiryKey = "auth_token_expiry"

    // MARK: - Published State
    @Published var jwt: String? {
        didSet { 
            if let token = jwt {
                saveAccessToken(token)
            } else {
                clearTokens()
            }
        }
    }
    @Published var userProfile: UserProfile?
    
    // MARK: - Private Token Management
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshTokenKey) }
        set { 
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: refreshTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: refreshTokenKey)
            }
        }
    }
    
    private var tokenExpiry: Date? {
        get { 
            let timestamp = UserDefaults.standard.double(forKey: tokenExpiryKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set { 
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: tokenExpiryKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
            }
        }
    }

    // MARK: - Auth State
    var isAuthenticated: Bool {
        guard let jwt = jwt, !jwt.isEmpty else { return false }
        return !isTokenExpired()
    }
    
    // MARK: - Token Expiration
    private func isTokenExpired() -> Bool {
        guard let expiry = tokenExpiry else { return true }
        return Date() >= expiry
    }
    
    private func shouldRefreshToken(bufferMinutes: Int = 5) -> Bool {
        guard let expiry = tokenExpiry else { return true }
        let bufferTime = TimeInterval(bufferMinutes * 60)
        return Date() >= (expiry - bufferTime)
    }

    // MARK: - JWT Storage (UserDefaults for now)
    private func saveAccessToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: accessTokenKey)
        // TODO: In production, store in Keychain instead of UserDefaults for security.
    }
    private func loadAccessToken() -> String? {
        // TODO: In production, load from Keychain.
        return UserDefaults.standard.string(forKey: accessTokenKey)
    }

    private func clearTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
    }

    private func loadTokensFromStorage() {
        self.jwt = loadAccessToken()
        // The refresh token and expiry are not directly managed by the @Published jwt property
        // as they are not part of the JWT itself.
        // If you need to manage them, you'd need to load them here or pass them to the @Published property.
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

    // MARK: - Token Management
    func setTokens(from response: AuthResponse) async {
        await MainActor.run {
            self.jwt = response.access_token
            self.refreshToken = response.refresh_token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in))
        }
    }
    
    func refreshTokens() async throws {
        guard let refreshToken = refreshToken else {
            throw AuthError.notAuthenticated
        }
        
        let network = NetworkService.shared
        let response = try await network.refreshTokens(refreshToken: refreshToken)
        await setTokens(from: response)
    }
    
    func getValidAccessToken() async throws -> String {
        if shouldRefreshToken() {
            try await refreshTokens()
        }
        
        guard let token = jwt else {
            throw AuthError.notAuthenticated
        }
        
        return token
    }

    // MARK: - Public API
    func loadFromStorage() {
        loadTokensFromStorage()
    }

    func login(email: String, password: String) async throws {
        let network = NetworkService.shared
        let auth = try await network.login(email: email, password: password)
        await setTokens(from: auth)
        
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
        await setTokens(from: auth)
        
        
        // Use PATCH /api/v1/users/me since POST /api/v1/users fails due to backend architecture
        let profile = try await network.updateUserProfile(
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
        let network = NetworkService.shared
        let profile = try await network.getCurrentUserProfile()
        await MainActor.run { self.userProfile = profile }
    }

    func updateCurrentUserProfile(displayName: String, email: String, bio: String?) async throws {
        let network = NetworkService.shared
        _ = try await network.updateCurrentUserProfile(
            displayName: displayName,
            email: email,
            bio: bio ?? "No bio yet"
        )
        try await refreshUserProfile()
    }

    func signIn(withJWT jwt: String) {
        Task { @MainActor in
            self.jwt = jwt
            saveAccessToken(jwt)
        }
    }
    
    func signOut() {
        Task { @MainActor in
            self.jwt = nil
            self.userProfile = nil
            clearTokens()
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
            clearTokens()
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