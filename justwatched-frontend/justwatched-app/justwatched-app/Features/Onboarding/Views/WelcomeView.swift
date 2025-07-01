import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 80))
                            .foregroundColor(.themeAccentYellow)
                        
                        Text("JustWatched")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text("Your social movie diary")
                            .font(.title3)
                            .foregroundColor(Color(hex: "393B3D"))
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
                                .foregroundColor(.white)
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