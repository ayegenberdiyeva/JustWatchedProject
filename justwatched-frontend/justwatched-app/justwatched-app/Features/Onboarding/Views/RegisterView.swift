import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Register")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                
                TextField("", text: $viewModel.email)
                    .placeholder(when: viewModel.email.isEmpty) {
                        Text("Email")
                            .foregroundColor(Color(hex: "393B3D"))
                            .fontWeight(.medium)
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Email address")
                    .accessibilityHint("Enter your email address for registration")
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                TextField("", text: $viewModel.displayName)
                    .placeholder(when: viewModel.displayName.isEmpty) {
                        Text("Username")
                            .foregroundColor(Color(hex: "393B3D"))
                            .fontWeight(.medium)
                    }
                    .textContentType(.nickname)
                    .autocapitalization(.words)
                    .accessibilityLabel("Username")
                    .accessibilityHint("Enter your username")
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                SecureField("", text: $viewModel.password)
                    .placeholder(when: viewModel.password.isEmpty) {
                        Text("Password, minimum 6 characters")
                            .foregroundColor(Color(hex: "393B3D"))
                            .fontWeight(.medium)
                    }
                    .textContentType(.newPassword)
                    .accessibilityLabel("Password")
                    .accessibilityHint("Enter your password (minimum 6 characters)")
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                SecureField("", text: $viewModel.confirmPassword)
                    .placeholder(when: viewModel.confirmPassword.isEmpty) {
                        Text("Confirm Password")
                            .foregroundColor(Color(hex: "393B3D"))
                            .fontWeight(.medium)
                    }
                    .textContentType(.newPassword)
                    .accessibilityLabel("Confirm password")
                    .accessibilityHint("Confirm your password")
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
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
                            .tint(.white)
                    } else {
                        Text("Register")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button("Already have an account? Login") {
                    dismiss()
                }
                .foregroundColor(.white)
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