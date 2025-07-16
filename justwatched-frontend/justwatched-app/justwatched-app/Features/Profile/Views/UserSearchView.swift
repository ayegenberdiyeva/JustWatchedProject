import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var results: [UserSearchResult] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var selectedUserId: String? = nil
    @State private var navigateToProfile = false
    @State private var gradientAngle: Double = 0.0
    @FocusState private var isSearchFocused: Bool
    
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
            searchBar
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
        .toolbar(.hidden, for: .tabBar)
    }
    
    private var animatedPlaceholderText: some View {
        let colorValue = AuthManager.shared.userProfile?.color ?? "red"
        return Text("Search by username...")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(colors: AnimatedPaletteGradientBackground.palette(for: colorValue)),
                    center: .topTrailing,
                    startAngle: .degrees(gradientAngle),
                    endAngle: .degrees(gradientAngle + 360)
                )
            )
            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
    }

    private var searchBar: some View {
        HStack {
            ZStack(alignment: .leading) {
                TextField(
                    "",
                    text: $searchText
                )
                .focused($isSearchFocused)
                .onSubmit {
                    isSearchFocused = false
                }
                .padding()
                .background(.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(20)
                
                if searchText.isEmpty {
                    animatedPlaceholderText
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)
            .onChange(of: searchText) { _, _ in
                Task { await searchUsers() }
            }
            .onAppear {
                // Start gradient animation
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    gradientAngle += 1.0
                }
            }
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .padding(.trailing)
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