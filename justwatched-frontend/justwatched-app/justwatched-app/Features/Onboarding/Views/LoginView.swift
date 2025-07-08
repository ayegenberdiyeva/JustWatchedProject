import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showResetPassword = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Login")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    TextField("", text: $viewModel.email)
                        .placeholder(when: viewModel.email.isEmpty) {
                            Text("Email")
                                .foregroundColor(Color(hex: "393B3D").opacity(0.8))
                                .fontWeight(.medium)
                        }
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Email address")
                        .accessibilityHint("Enter your email address to login")
                        .padding()
                        .background(Color(hex: "393B3D").opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    SecureField("", text: $viewModel.password)
                        .placeholder(when: viewModel.password.isEmpty) {
                            Text("Password")
                                .foregroundColor(Color(hex: "393B3D").opacity(0.8))
                                .fontWeight(.medium)
                        }
                        .textContentType(.password)
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password")
                        .padding()
                        .background(Color(hex: "393B3D").opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                    }
                    
                    Button("Forgot Password?") {
                        showResetPassword = true
                    }
                    .font(.footnote)
                    .foregroundColor(Color(hex: "393B3D"))
                    .padding(.top, -8)
                    
                    Button(action: {
                        Task { await viewModel.login() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Login")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button("Don't have an account? Register") {
                        showRegister = true
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }
}

#Preview {
    LoginView()
} 
 