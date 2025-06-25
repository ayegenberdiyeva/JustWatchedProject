import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themePrimaryDark.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 80))
                            .foregroundColor(.themeAccentYellow)
                        
                        Text("FilmLog AI")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.themeNeutralLight)
                        
                        Text("Your personal movie companion")
                            .font(.title3)
                            .foregroundColor(.themeNeutralLight.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: { showLogin = true }) {
                            Text("Login")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themeAccentYellow)
                                .foregroundColor(.themePrimaryDark)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { showRegister = true }) {
                            Text("Register")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themePrimaryGrey)
                                .foregroundColor(.themeNeutralLight)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
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