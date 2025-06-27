import SwiftUI

struct MainTabView: View {
    @State private var showAddReview = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            SearchResultsView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            AddReviewView()
                .tabItem {
                    Label("Add Review", systemImage: "plus")
                }
            
            LobbyView()
                .tabItem {
                    Label("Room", systemImage: "person.3.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(.themeAccentYellow)
        .background(Color.themePrimaryDark)
    }
}

#Preview {
    MainTabView()
}
