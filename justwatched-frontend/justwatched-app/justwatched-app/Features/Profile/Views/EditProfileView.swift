import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: EditProfileViewModel
    @State private var showFloatingPanel = false
    @State private var selectedField: EditField = .name
    
    enum EditField {
        case name, bio, theme
    }
    
    var body: some View {
        NavigationStack {

            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {

                    Text("Tap to change")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.top, 40)

                    // Profile Fields List
                    VStack(spacing: 0) {
                        profileFieldRow(title: "Name", value: viewModel.displayName.isEmpty ? "Add your name" : viewModel.displayName) {
                            selectedField = .name
                            showFloatingPanel = true
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        profileFieldRow(title: "Bio", value: viewModel.bio.isEmpty ? "Add a bio" : viewModel.bio) {
                            selectedField = .bio
                            showFloatingPanel = true
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        profileFieldRow(title: "Theme", value: viewModel.color.capitalized) {
                            selectedField = .theme
                            showFloatingPanel = true
                        }
                    }
                    .background(Color(hex: "393B3D").opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: viewModel.success) {
                if viewModel.success {
                    dismiss()
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showFloatingPanel) {
                floatingPanelView
            }
        }
    }
    
    private func profileFieldRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                Text(value)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 20)
            }
            .frame(height: 50)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var floatingPanelView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    switch selectedField {
                    case .name:
                        nameEditView
                    case .bio:
                        bioEditView
                    case .theme:
                        themeEditView
                    }
                }
                .padding(24)
            }
            // .frame(height: 400) // Fixed height
            .navigationTitle(selectedFieldTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showFloatingPanel = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFloatingPanel = false
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(200)]) // Match the frame height
        .presentationDragIndicator(.visible)
    }
    
    private var selectedFieldTitle: String {
        switch selectedField {
        case .name: return "Edit Name"
        case .bio: return "Edit Bio"
        case .theme: return "Choose Theme"
        }
    }
    
    private var nameEditView: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Enter your name", text: $viewModel.displayName)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color(hex: "393B3D").opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
                .accentColor(.white)
        }
    }
    
    private var bioEditView: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Tell us about yourself", text: $viewModel.bio, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .lineLimit(3...6)
                .padding()
                .background(Color(hex: "393B3D").opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
                .accentColor(.white)
                .onChange(of: viewModel.bio) { newValue in
                    if newValue.count > 35 {
                        viewModel.bio = String(newValue.prefix(35))
                    }
                }
            
            HStack {
                Spacer()
                Text("\(viewModel.bio.count)/35")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var themeEditView: some View {
        HStack(spacing: 20) {
            ForEach(colorChoices, id: \.self) { color in
                Button(action: {
                    viewModel.color = color
                }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(colorMap[color] ?? .white)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: viewModel.color == color ? 2 : 0)
                            )
                        
                        Text(color.capitalized)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private let colorChoices = ["red", "yellow", "green", "blue", "pink"]
    private let colorMap: [String: Color] = [
        "red": .red,
        "yellow": .yellow,
        "green": .green,
        "blue": .blue,
        "pink": .pink
    ]
}

#Preview {
    EditProfileView(viewModel: EditProfileViewModel(profileViewModel: ProfileViewModel()))
} 
 