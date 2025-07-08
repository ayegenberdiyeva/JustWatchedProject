import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var displayName: String = ""
    @Published var error: String?
    @Published var isLoading: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var isRegistered: Bool = false
    @Published var passwordResetSent: Bool = false

    private let authManager = AuthManager.shared
    private let networkService = NetworkService.shared

    func login() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        
        // Validate input
        guard !email.isEmpty else {
            error = "Email is required."
            return
        }
        guard !password.isEmpty else {
            error = "Password is required."
            return
        }
        
        do {
            try await authManager.login(email: email, password: password)
            isLoggedIn = true
        } catch {
            // Handle specific error types
            if let authError = error as? AuthManager.AuthError {
                switch authError {
                case .invalidCredentials:
                    self.error = "Invalid email or password. Please try again."
                case .notAuthenticated:
                    self.error = "Authentication failed. Please try again."
                case .profileNotFound:
                    self.error = "User profile not found. Please contact support."
                case .networkError(let message):
                    self.error = "Network error: \(message)"
                }
            } else if let networkError = error as? NetworkError {
                switch networkError {
                case .requestFailed(let statusCode):
                    if statusCode == 401 {
                        self.error = "Invalid email or password. Please try again."
                    } else if statusCode == 404 {
                        self.error = "User not found. Please check your credentials."
                    } else {
                        self.error = "Login failed. Please try again later."
                    }
                case .invalidURL:
                    self.error = "Invalid request. Please try again."
                case .decodingFailed:
                    self.error = "Server response error. Please try again."
                case .invalidResponse:
                    self.error = "Server error. Please try again later."
                }
            } else {
                self.error = error.localizedDescription
            }
            // Don't set isLoggedIn to true on error
            isLoggedIn = false
        }
    }

    func register() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        
        // Validate input
        guard !email.isEmpty else {
            error = "Email is required."
            return
        }
        guard !displayName.isEmpty else {
            error = "Username is required."
            return
        }
        guard !password.isEmpty else {
            error = "Password is required."
            return
        }
        guard password == confirmPassword else {
            error = "Passwords do not match."
            return
        }
        guard password.count >= 6 else {
            error = "Password must be at least 6 characters long."
            return
        }
        
        do {
            try await authManager.register(email: email, password: password, displayName: displayName)
            isRegistered = true
        } catch {
            // Handle specific error types
            if let authError = error as? AuthManager.AuthError {
                switch authError {
                case .invalidCredentials:
                    self.error = "Registration failed. Please try again."
                case .notAuthenticated:
                    self.error = "Authentication failed. Please try again."
                case .profileNotFound:
                    self.error = "Profile creation failed. Please try again."
                case .networkError(let message):
                    self.error = "Network error: \(message)"
                }
            } else if let networkError = error as? NetworkError {
                switch networkError {
                case .requestFailed(let statusCode):
                    if statusCode == 409 {
                        self.error = "Email already exists. Please use a different email or try logging in."
                    } else if statusCode == 400 {
                        self.error = "Invalid registration data. Please check your information."
                    } else {
                        self.error = "Registration failed. Please try again later."
                    }
                case .invalidURL:
                    self.error = "Invalid request. Please try again."
                case .decodingFailed:
                    self.error = "Server response error. Please try again."
                case .invalidResponse:
                    self.error = "Server error. Please try again later."
                }
            } else {
                self.error = error.localizedDescription
            }
            // Don't set isRegistered to true on error
            isRegistered = false
        }
    }

    // func logout() {
    //     authManager.logout()
    //     isLoggedIn = false
    //     isRegistered = false
    //     passwordResetSent = false
    //     email = ""
    //     password = ""
    //     confirmPassword = ""
    // }

    func requestPasswordReset() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await networkService.requestPasswordReset(email: email)
            passwordResetSent = true
        } catch {
            self.error = error.localizedDescription
        }
    }
} 