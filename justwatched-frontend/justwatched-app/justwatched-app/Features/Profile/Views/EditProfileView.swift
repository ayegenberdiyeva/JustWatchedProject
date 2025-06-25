import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: EditProfileViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themePrimaryDark.ignoresSafeArea()
                VStack {
                    Form {
                        Section {
                            TextField("", text: $viewModel.displayName)
                                .placeholder(when: viewModel.displayName.isEmpty) {
                                    Text("Display Name")
                                        .foregroundColor(.themeNeutralLight.opacity(0.8))
                                        .fontWeight(.medium)
                                }
                                .textContentType(.nickname)
                                .autocapitalization(.words)
                                .disableAutocorrection(false)
                                .accessibilityLabel("Display name")
                                .accessibilityHint("Enter your display name")
                                .font(.system(size: 18, design: .rounded))
                                .padding(8)
                                .background(Color.themePrimaryGrey)
                                .foregroundColor(.themeNeutralLight)
                                .cornerRadius(12)
                            
                            TextField("", text: $viewModel.bio)
                                .placeholder(when: viewModel.bio.isEmpty) {
                                    Text("Bio")
                                        .foregroundColor(.themeNeutralLight.opacity(0.8))
                                        .fontWeight(.medium)
                                }
                                .textContentType(.none)
                                .autocapitalization(.sentences)
                                .accessibilityLabel("Bio")
                                .accessibilityHint("Enter a short bio about yourself")
                                .font(.system(size: 18, design: .rounded))
                                .padding(8)
                                .background(Color.themePrimaryGrey)
                                .foregroundColor(.themeNeutralLight)
                                .cornerRadius(12)
                        } header: {
                            Text("Profile Information")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .listRowBackground(Color.themePrimaryGrey)
                        .padding(.vertical, 8)
                        
                        if let error = viewModel.error {
                            Section {
                                Text(String(describing: error))
                                    .foregroundColor(.red)
                            }
                            .listRowBackground(Color.themePrimaryGrey)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 32)
                    
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themePrimaryGrey)
                                .foregroundColor(.themeNeutralLight)
                                .cornerRadius(16)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.saveProfile()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.themeNeutralLight)
                            } else {
                                Text("Save")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.themeAccentYellow)
                                    .foregroundColor(.themePrimaryDark)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.themePrimaryDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: viewModel.success) {
                if viewModel.success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    EditProfileView(viewModel: EditProfileViewModel(profileViewModel: ProfileViewModel()))
} 
