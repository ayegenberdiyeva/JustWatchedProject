import SwiftUI

struct ReviewModalView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("ReviewModalView")
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    ReviewModalView()
} 