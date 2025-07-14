import SwiftUI

struct CreateRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var roomDescription = ""
    @State private var maxParticipants = 10
    @State private var isLoading = false
    @State private var error: String?
    @State private var gradientAngle: Double = 0.0
    
    let onComplete: (String, String?, Int) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        formSection
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Create Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createRoom()
                    }
                    .foregroundColor(isFormValid ? preferredColor : .gray)
                    .disabled(!isFormValid || isLoading)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
            .onAppear {
                startGradientAnimation()
            }
            .onDisappear {
                stopGradientAnimation()
            }
        }
    }
    
    private var headerSection: some View {
        ZStack {
            let colorValue = AuthManager.shared.userProfile?.color ?? "red"
            // AnimatedPaletteGradientBackground(paletteName: colorValue)
            //     .cornerRadius(32)
            //     .overlay(Color.black.opacity(0.5).cornerRadius(32))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Create ")
                        .font(.title2)
                        .foregroundStyle(
                            AngularGradient(
                                gradient: Gradient(colors: AnimatedPaletteGradientBackground.palette(for: colorValue)),
                                center: .topTrailing,
                                startAngle: .degrees(gradientAngle),
                                endAngle: .degrees(gradientAngle + 360)
                            )
                        )
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
                    Text("Room")
                        .font(.title2.bold())
                        .foregroundStyle(
                            AngularGradient(
                                gradient: Gradient(colors: AnimatedPaletteGradientBackground.palette(for: colorValue)),
                                center: .topTrailing,
                                startAngle: .degrees(gradientAngle),
                                endAngle: .degrees(gradientAngle + 360)
                            )
                        )
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: gradientAngle)
                }
                Text("Set up a new group watch session")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            // .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        // .cornerRadius(32)
        // .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Room Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Room Name")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Enter room name", text: $roomName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .accentColor(preferredColor)
            }
            
            // Room Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Enter room description", text: $roomDescription, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .accentColor(preferredColor)
                    .lineLimit(3...6)
            }
            
            // Max Participants
            VStack(alignment: .leading, spacing: 8) {
                Text("Maximum Participants")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(maxParticipants)")
                        .font(.title2.bold())
                        .foregroundColor(preferredColor)
                        .frame(width: 60)
                    
                    Slider(value: Binding(
                        get: { Double(maxParticipants) },
                        set: { maxParticipants = Int($0) }
                    ), in: 2...10, step: 1)
                    .accentColor(preferredColor)
                    
                    Text("10")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                }
                .padding()
                .background(Color(hex: "393B3D").opacity(0.3))
                .cornerRadius(12)
            }
            
            // Info Section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(preferredColor)
                    Text("Room Information")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "person.2", text: "You'll be the room owner")
                    InfoRow(icon: "sparkles", text: "AI will analyze all participants' taste profiles")
                    InfoRow(icon: "hand.raised", text: "Participants can vote on movie recommendations")
                    InfoRow(icon: "clock", text: "Processing takes 10-30 seconds")
                }
            }
            .padding()
            .background(Color(hex: "393B3D").opacity(0.3))
            .cornerRadius(16)
            
            // Create Button
            if isLoading {
                HStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Creating room...")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "393B3D").opacity(0.3))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    private var isFormValid: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        roomName.count <= 100
    }
    
    private var preferredColor: Color {
        switch AuthManager.shared.userProfile?.color {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .white
        }
    }
    
    private func createRoom() {
        guard isFormValid else { return }
        
        isLoading = true
        error = nil
        
        let trimmedName = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = roomDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        
        onComplete(trimmedName, finalDescription, maxParticipants)
        dismiss()
    }
    
    private func startGradientAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            gradientAngle += 1.0
        }
    }
    
    private func stopGradientAnimation() {
        gradientAngle = 0.0
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

#Preview {
    CreateRoomView { name, description, maxParticipants in
        print("Creating room: \(name)")
    }
} 