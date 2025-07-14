import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: EditProfileViewModel
    private let colorChoices = ["red", "yellow", "green", "blue", "pink"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer(minLength: 24)
                    VStack(spacing: 28) {
                        Text("Edit Profile")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        Divider().background(Color.white.opacity(0.12))
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Name and Bio:")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            displayNameField
                            bioFieldWithCounter
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color of choice:")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            colorPicker
                        }
                        if let error = viewModel.error {
                            Text(String(describing: error))
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.top, 4)
                        }
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(hex: "393B3D").opacity(0.5))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.footnote.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "393B3D").opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        Button(action: {
                            Task {
                                await viewModel.saveProfile()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                            } else {
                                Text("Save")
                                    .font(.footnote.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.success) {
                if viewModel.success {
                    dismiss()
                }
            }
        }
    }

    private var displayNameField: some View {
        TextField("", text: $viewModel.displayName)
            .placeholder(when: viewModel.displayName.isEmpty) {
                Text("My name is...")
                    .foregroundColor(Color(hex: "393B3D").opacity(0.8))
                    .fontWeight(.medium)
            }
            .textContentType(.nickname)
            .autocapitalization(.words)
            .disableAutocorrection(false)
            .accessibilityLabel("Display name")
            .accessibilityHint("Enter your display name")
            .font(.footnote)
            .padding(12)
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(14)
    }

    private var bioFieldWithCounter: some View {
        ZStack {
            TextField("", text: $viewModel.bio)
                .placeholder(when: viewModel.bio.isEmpty) {
                    Text("About me...")
                        .foregroundColor(Color(hex: "393B3D").opacity(0.8))
                        .fontWeight(.medium)
                }
                .textContentType(.none)
                .autocapitalization(.sentences)
                .accessibilityLabel("Bio")
                .accessibilityHint("Enter a short bio about yourself")
                .font(.footnote)
                .padding(12)
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(14)
                .onChange(of: viewModel.bio) { newValue in
                    if newValue.count > 35 {
                        viewModel.bio = String(newValue.prefix(35))
                    }
                }
            HStack {
                Spacer()
                Text("\(viewModel.bio.count)/35")
                    .font(.caption)
                    .foregroundColor(Color(hex: "393B3D").opacity(0.7))
                    .padding(.trailing, 16)
            }
        }
    }

    private var colorPicker: some View {
        let colorMap: [String: Color] = [
            "red": .red,
            "yellow": .yellow,
            "green": .green,
            "blue": .blue,
            "pink": .pink
        ]
        return HStack(spacing: 0) {
            ForEach(colorChoices, id: \.self) { color in
                Button(action: {
                    viewModel.color = color
                }) {
                    Text(color.capitalized)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.color == color ? colorMap[color, default: .white] : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if viewModel.color == color {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colorMap[color, default: .white].opacity(0.5), lineWidth: 8)
                                        .blur(radius: 6)
                                        .offset(x: 0, y: 0)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "393B3D").opacity(0.5))
        )
        .padding(.vertical, 4)
    }
}

#Preview {
    EditProfileView(viewModel: EditProfileViewModel(profileViewModel: ProfileViewModel()))
} 
 