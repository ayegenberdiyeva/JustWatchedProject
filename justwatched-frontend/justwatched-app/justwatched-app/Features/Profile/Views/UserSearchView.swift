import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var results: [UserSearchResult] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var selectedUserId: String? = nil
    @State private var navigateToProfile = false
    
    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search by username").foregroundColor(preferredColor)
                )
                .padding()
                .background(preferredColor.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(preferredColor, lineWidth: 1)
                )
                .padding(.horizontal)
                .onChange(of: searchText) { newValue in
                    Task { await searchUsers() }
                }
                if isLoading {
                    ProgressView().padding(.trailing)
                }
            }
            if let error = error {
                Text(error).foregroundColor(.red).padding()
            }
            List(results) { user in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.display_name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .listRowBackground(Color.black)
                .contentShape(Rectangle())
                .onTapGesture { 
                    selectedUserId = user.user_id
                    navigateToProfile = true
                    print("🔍 Selected user ID: \(user.user_id)")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .background(Color.black)
        }
        .navigationTitle("Search Users")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(isPresented: $navigateToProfile) {
            if let userId = selectedUserId {
                OtherUserProfileView(userId: userId)
            }
        }
    }
    

    
    private func searchUsers() async {
        guard !searchText.isEmpty else { results = []; return }
        isLoading = true; error = nil
        do {
            let found = try await NetworkService.shared.searchUsers(displayName: searchText)
            results = found
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 