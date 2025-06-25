import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.themePrimaryDark.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Register")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.themeNeutralLight)
                
                TextField("", text: $viewModel.email)
                    .placeholder(when: viewModel.email.isEmpty) {
                        Text("Email")
                            .foregroundColor(.themeNeutralLight.opacity(0.8))
                            .fontWeight(.medium)
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Email address")
                    .accessibilityHint("Enter your email address for registration")
                    .padding()
                    .background(Color.themePrimaryGrey)
                    .foregroundColor(.themeNeutralLight)
                    .cornerRadius(8)
                
                TextField("", text: $viewModel.displayName)
                    .placeholder(when: viewModel.displayName.isEmpty) {
                        Text("Display Name (optional)")
                            .foregroundColor(.themeNeutralLight.opacity(0.8))
                            .fontWeight(.medium)
                    }
                    .textContentType(.nickname)
                    .autocapitalization(.words)
                    .accessibilityLabel("Display name")
                    .accessibilityHint("Enter your display name (optional)")
                    .padding()
                    .background(Color.themePrimaryGrey)
                    .foregroundColor(.themeNeutralLight)
                    .cornerRadius(8)
                
                SecureField("", text: $viewModel.password)
                    .placeholder(when: viewModel.password.isEmpty) {
                        Text("Password")
                            .foregroundColor(.themeNeutralLight.opacity(0.8))
                            .fontWeight(.medium)
                    }
                    .textContentType(.newPassword)
                    .accessibilityLabel("Password")
                    .accessibilityHint("Enter your password (minimum 6 characters)")
                    .padding()
                    .background(Color.themePrimaryGrey)
                    .foregroundColor(.themeNeutralLight)
                    .cornerRadius(8)
                
                SecureField("", text: $viewModel.confirmPassword)
                    .placeholder(when: viewModel.confirmPassword.isEmpty) {
                        Text("Confirm Password")
                            .foregroundColor(.themeNeutralLight.opacity(0.8))
                            .fontWeight(.medium)
                    }
                    .textContentType(.newPassword)
                    .accessibilityLabel("Confirm password")
                    .accessibilityHint("Confirm your password")
                    .padding()
                    .background(Color.themePrimaryGrey)
                    .foregroundColor(.themeNeutralLight)
                    .cornerRadius(8)
                
                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    Task {
                        await viewModel.register()
                        if viewModel.isRegistered {
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.themeNeutralLight)
                    } else {
                        Text("Register")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themeAccentYellow)
                            .foregroundColor(.themePrimaryDark)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button("Already have an account? Login") {
                    dismiss()
                }
                .foregroundColor(.themeNeutralLight)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    RegisterView()
} 