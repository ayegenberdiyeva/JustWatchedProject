import SwiftUI

struct PasswordSentView: View {
    let email: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.themePrimaryDark.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.themeAccentYellow)
                
                Text("Check Your Email")
                    .font(.title)
                    .bold()
                    .foregroundColor(.themeNeutralLight)
                
                Text("We've sent password reset instructions to:\n\(email)")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.themeNeutralLight.opacity(0.7))
                
                Text("If you don't see the email, check your spam folder.")
                    .font(.caption)
                    .foregroundColor(.themeNeutralLight.opacity(0.7))
                
                Button("Back to Login") {
                    // Dismiss all the way back to login
                    dismiss()
                    dismiss()
                }
                .foregroundColor(.themeAccentYellow)
                .padding(.top, 32)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    PasswordSentView(email: "user@example.com")
} 