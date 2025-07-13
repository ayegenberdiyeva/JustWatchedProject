import SwiftUI

struct AnimatedPaletteGradientBackground: View {
    let paletteName: String
    @State private var gradientAngle: Double = 0.0
    @State private var timer: Timer?

    static func palette(for name: String) -> [Color] {
        let baseColors: [Color]
        switch name {
        case "yellow":
            baseColors = [
                Color(red: 1.0, green: 0.8, blue: 0.2), // gold
                Color(red: 1.0, green: 0.9, blue: 0.4), // yellow
                Color(red: 1.0, green: 1.0, blue: 0.7), // light yellow
                Color(red: 1.0, green: 0.7, blue: 0.2), // orange
                Color(red: 1.0, green: 1.0, blue: 0.5)  // lemon
            ]
        case "green":
            baseColors = [
                Color(red: 0.0, green: 0.4, blue: 0.2), // dark green
                Color(red: 0.1, green: 0.7, blue: 0.3), // green
                Color(red: 0.5, green: 1.0, blue: 0.7), // light green
                Color(red: 0.2, green: 1.0, blue: 0.7), // teal
                Color(red: 0.7, green: 1.0, blue: 0.8)  // mint
            ]
        case "blue":
            baseColors = [
                Color(red: 0.1, green: 0.1, blue: 0.4), // navy
                Color(red: 0.2, green: 0.4, blue: 0.8), // blue
                Color(red: 0.4, green: 0.7, blue: 1.0), // sky blue
                Color(red: 0.2, green: 1.0, blue: 1.0), // cyan
                Color(red: 0.7, green: 0.9, blue: 1.0)  // light blue
            ]
        case "pink":
            baseColors = [
                Color(red: 1.0, green: 0.0, blue: 0.5), // magenta
                Color(red: 1.0, green: 0.4, blue: 0.7), // pink
                Color(red: 1.0, green: 0.7, blue: 0.9), // light pink
                Color(red: 1.0, green: 0.5, blue: 0.7), // rose
                Color(red: 1.0, green: 0.8, blue: 0.7)  // peach
            ]
        default: // "red"
            baseColors = [
                Color(red: 0.4, green: 0.0, blue: 0.0), // dark red
                Color(red: 0.8, green: 0.1, blue: 0.1), // red
                Color(red: 1.0, green: 0.3, blue: 0.2), // orange-red
                Color(red: 1.0, green: 0.5, blue: 0.5), // light red
                Color(red: 1.0, green: 0.4, blue: 0.3)  // coral
            ]
        }
        
        // Make first and last color the same for seamless gradient
        if let firstColor = baseColors.first {
            return baseColors + [firstColor]
        }
        return baseColors
    }

    var body: some View {
        let colors = Self.palette(for: paletteName)
        
        return AngularGradient(
            gradient: Gradient(colors: colors),
            center: .topTrailing,
            startAngle: .degrees(gradientAngle),
            endAngle: .degrees(gradientAngle + 360)
        )
        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                gradientAngle += 1.0
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: paletteName) { _ in
            // Reset angle when palette changes for smooth transition
            gradientAngle = 0.0
        }
    }
}

#Preview {
    AnimatedPaletteGradientBackground(paletteName: "red")
        .frame(width: 200, height: 200)
        .cornerRadius(20)
} 