import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAccountAlert = false
    @State private var showLogoutAlert = false
    @State private var navigateToManageCollections = false
    
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
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundColor(preferredColor)
                    Text("Settings")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Settings Options
                VStack(spacing: 16) {
                    // Manage Collections
                    NavigationLink(destination: ManageCollectionsView(), isActive: $navigateToManageCollections) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(preferredColor)
                                .frame(width: 24)
                            Text("Manage Collections")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .padding()
                        .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Logout
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Logout")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                        }
                        .padding()
                        .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Delete Account
                    Button(action: {
                        showDeleteAccountAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Delete Account")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                        }
                        .padding()
                        .background(Color(hex: "393B3D").opacity(0.3))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                AuthManager.shared.signOut()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Implement delete account functionality
                print("Delete account functionality to be implemented")
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
}

#Preview {
    SettingsView()
} 