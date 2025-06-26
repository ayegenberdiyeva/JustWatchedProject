import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showAddReview = false
        
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themePrimaryDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                        statsCard
                        actionButtons
                        addReviewButton
                        reviewsList
                    }
                    .padding(.top)
                }
                .refreshable {
                    await viewModel.fetchProfile()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.themePrimaryDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.fetchProfile()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.themeAccentYellow)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: EditProfileViewModel(profileViewModel: viewModel))
            }
            .sheet(isPresented: $showAddReview) {
                AddReviewView(onReviewAdded: {
                    Task {
                        await viewModel.fetchProfile()
                    }
                })
            }
            .task {
                await viewModel.fetchProfile()
            }
            .onAppear {
                // Refresh profile when view appears
                Task {
                    await viewModel.fetchProfile()
                }
            }
            .onChange(of: showEditProfile) {
                if !showEditProfile {
                    Task {
                        await viewModel.fetchProfile()
                    }
                }
            }
            .onChange(of: showAddReview) {
                if !showAddReview {
                    Task {
                        await viewModel.fetchProfile()
                    }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .foregroundColor(.themeAccentYellow)
                .background(Circle().fill(Color.themePrimaryGrey).shadow(radius: 4))
                .padding(.top, 16)

            Text(viewModel.userProfile?.displayName ?? "No Display Name")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.themeNeutralLight)

            Text(viewModel.userProfile?.email ?? "")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.themeAccentYellow.opacity(0.7))
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.themePrimaryGrey)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var statsCard: some View {
        HStack(spacing: 0) {
            statView(title: "Reviews", value: "\(viewModel.reviews.count)")
            Divider().frame(height: 40).background(Color.themeNeutralLight.opacity(0.2))
            statView(title: "Watchlist", value: "0")
            Divider().frame(height: 40).background(Color.themeNeutralLight.opacity(0.2))
            statView(title: "Groups", value: "0")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.themePrimaryGrey)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showEditProfile = true }) {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccentYellow)
                    .foregroundColor(.themePrimaryDark)
                    .cornerRadius(16)
            }
            
            Button(action: { AuthManager.shared.signOut() }) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    private var addReviewButton: some View {
        Button(action: { showAddReview = true }) {
            Label("Add Review", systemImage: "plus")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.themeAccentYellow.opacity(0.15))
                .foregroundColor(.themeAccentYellow)
                .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var reviewsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Reviews")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.themeNeutralLight)
                .padding(.bottom, 4)
            if viewModel.reviews.isEmpty {
                Text("No reviews yet.")
                    .foregroundColor(.themeAccentYellow.opacity(0.7))
                    .padding(.top, 8)
            } else {
                ForEach(viewModel.reviews) { review in
                    ReviewCard(review: review)
                }
            }
        }
        .padding()
        .background(Color.themePrimaryGrey)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.themeAccentYellow)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.themeAccentYellow.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Movie: \(review.movieTitle)")
                    .font(.headline)
                    .foregroundColor(Color("PrimaryText"))
                Spacer()
                Text("\(review.rating)/5")
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryAccent"))
            }
            
            if let content = review.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryAccent").opacity(0.7))
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ProfileView()
}
