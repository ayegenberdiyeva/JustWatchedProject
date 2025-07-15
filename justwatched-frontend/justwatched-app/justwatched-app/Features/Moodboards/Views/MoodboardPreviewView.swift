import SwiftUI

struct MoodboardPreviewView: View {
    var body: some View {
        Text("MoodboardPreviewView")
            .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    MoodboardPreviewView()
} 