import SwiftUI

struct ResetPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                
                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "393B3D"))
                
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
                    .accessibilityHint("Enter your email address to receive password reset instructions")
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
                        await viewModel.requestPasswordReset()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Reset Instructions")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themeAccentYellow)
                            .foregroundColor(.themePrimaryDark)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button("Back to Login") {
                    dismiss()
                }
                .foregroundColor(.white)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $viewModel.passwordResetSent) {
                PasswordSentView(email: viewModel.email)
            }
        }
    }
}

#Preview {
    ResetPasswordView()
} 