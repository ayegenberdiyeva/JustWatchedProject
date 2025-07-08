import SwiftUI

struct FriendsFeedView: View {
    @State private var navigateToUserSearch = false
    @State private var navigateToFriendRequests = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Text("Friends Feed")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                    // TODO: Add recent reviews from friends here
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { navigateToUserSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { navigateToFriendRequests = true }) {
                        Image(systemName: "bell")
                    }
                }
            }
            .background(
                NavigationLink(destination: UserSearchView(), isActive: $navigateToUserSearch) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: FriendRequestsView(), isActive: $navigateToFriendRequests) { EmptyView() }
                    .hidden()
            )
        }
    }
}

#Preview {
    FriendsFeedView()
} 