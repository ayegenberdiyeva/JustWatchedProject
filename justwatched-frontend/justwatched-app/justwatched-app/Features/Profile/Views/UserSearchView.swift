import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var results: [UserSearchResult] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var selectedUserId: String? = nil
    @State private var navigateToProfile = false
    @StateObject private var friendVM = ProfileFriendViewModel()
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search by display name", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
                        Circle().fill(Color(user.color ?? "gray")).frame(width: 32, height: 32)
                        Text(user.display_name)
                            .font(.headline)
                        Spacer()
                        friendActionButton(for: user)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { 
                    selectedUserId = user.user_id
                    navigateToProfile = true
                    print("🔍 Selected user ID: \(user.user_id)")
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
        }
        .navigationTitle("Search Users")
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(isPresented: $navigateToProfile) {
            if let userId = selectedUserId {
                OtherUserProfileView(userId: userId)
            }
        }
    }
    
    private func friendActionButton(for user: UserSearchResult) -> some View {
        switch user.friend_status ?? "not_friends" {
        case "not_friends":
            return AnyView(Button("Add Friend") {
                Task { await friendVM.sendRequest(to: user.user_id) }
            }.buttonStyle(.borderedProminent))
        case "pending_sent":
            return AnyView(Button("Request Sent") {}.disabled(true).buttonStyle(.bordered))
        case "pending_received":
            return AnyView(HStack(spacing: 4) {
                Button("Accept") {
                    if let reqId = friendVM.pendingRequestId {
                        Task { await friendVM.respondToRequest(requestId: reqId, action: "accept") }
                    }
                }.buttonStyle(.borderedProminent)
                Button("Decline") {
                    if let reqId = friendVM.pendingRequestId {
                        Task { await friendVM.respondToRequest(requestId: reqId, action: "decline") }
                    }
                }.buttonStyle(.bordered)
            })
        case "friends":
            return AnyView(Button("Remove Friend") {
                Task { await friendVM.removeFriend(userId: user.user_id) }
            }.buttonStyle(.bordered))
        default:
            return AnyView(EmptyView())
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