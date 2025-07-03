import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                // Centered logo text (identical to SplashScreenView)
                Text("Just\nWatched.")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.bottom, 40)
                // Bottom-aligned button set
                VStack(spacing: 16) {
                    Button(action: { showLogin = true }) {
                        Text("Log in")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    Button(action: { showRegister = true }) {
                        Text("Sign in")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themePrimaryGrey)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .sheet(isPresented: $showLogin) {
                NavigationStack {
                    LoginView()
                }
            }
            .sheet(isPresented: $showRegister) {
                NavigationStack {
                    RegisterView()
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
} 