import Foundation
import SwiftUI

@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile? = nil
    @Published var isLoading = false
    @Published var error: String? = nil
    
    func fetchUserProfile(userId: String) async {
        isLoading = true; error = nil
        do {
            let profile = try await NetworkService.shared.getOtherUserProfile(userId: userId)
            self.userProfile = profile
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 