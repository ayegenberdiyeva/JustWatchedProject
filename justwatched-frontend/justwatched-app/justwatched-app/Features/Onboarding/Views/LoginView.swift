import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showResetPassword = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themePrimaryDark.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Login")
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
                        .accessibilityHint("Enter your email address to login")
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
                        .textContentType(.password)
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password")
                        .padding()
                        .background(Color.themePrimaryGrey)
                        .foregroundColor(.themeNeutralLight)
                        .cornerRadius(8)
                    
                    Button("Forgot Password?") {
                        showResetPassword = true
                    }
                    .font(.footnote)
                    .foregroundColor(.themeAccentYellow)
                    .padding(.top, -8)
                    
                    Button(action: {
                        Task { await viewModel.login() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.themeNeutralLight)
                        } else {
                            Text("Login")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themeAccentYellow)
                                .foregroundColor(.themePrimaryDark)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button("Don't have an account? Register") {
                        showRegister = true
                    }
                    .foregroundColor(.themeNeutralLight)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showResetPassword) {
                NavigationStack {
                    ResetPasswordView()
                }
            }
            .alert("Login Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "An unknown error occurred")
            }
            .onChange(of: viewModel.error) {
                showErrorAlert = viewModel.error != nil
            }
        }
    }
}

#Preview {
    LoginView()
} 
 