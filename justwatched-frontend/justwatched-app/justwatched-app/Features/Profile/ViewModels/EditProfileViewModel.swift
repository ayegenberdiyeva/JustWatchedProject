import SwiftUI

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var bio: String = ""
    @Published var avatarUrl: String = ""
    @Published var color: String = "red"
    @Published var isLoading = false
    @Published var error: Error?
    @Published var success = false
    
    private let networkService = NetworkService.shared
    private let profileViewModel: ProfileViewModel
    
    init(profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
        if let profile = AuthManager.shared.userProfile {
            self.displayName = profile.displayName ?? ""
            self.email = profile.email
            self.bio = profile.bio ?? ""
            self.avatarUrl = profile.avatarUrl ?? ""
            self.color = profile.color ?? "red"
        }
    }
    
    func saveProfile() async {
        isLoading = true
        error = nil
        success = false
        
        do {
            try await networkService.updateProfile(
                displayName: displayName.isEmpty ? nil : displayName,
                email: email.isEmpty ? nil : email,
                bio: bio.isEmpty ? nil : bio,
                avatarUrl: avatarUrl.isEmpty ? nil : avatarUrl,
                color: color
            )
            try await AuthManager.shared.refreshUserProfile()
            await profileViewModel.fetchProfile()
            success = true
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
} 