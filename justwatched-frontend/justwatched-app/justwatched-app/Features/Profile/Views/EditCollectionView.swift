import SwiftUI

struct EditCollectionView: View {
    let collection: Collection
    let preferredColor: Color
    var onComplete: (String, String, String) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var visibility: String

    init(collection: Collection, preferredColor: Color, onComplete: @escaping (String, String, String) -> Void, onCancel: @escaping () -> Void) {
        self.collection = collection
        self.preferredColor = preferredColor
        self.onComplete = onComplete
        self.onCancel = onCancel
        
        // Initialize state with current collection values
        _name = State(initialValue: collection.name)
        _description = State(initialValue: collection.description ?? "")
        _visibility = State(initialValue: collection.visibility)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Collection")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 40)
                .padding(.bottom, 24)
                .padding(.horizontal, 24)
            Divider().background(Color.white.opacity(0.12))
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    TextField("Name", text: $name)
                        .padding(14)
                        .background(Color.secondary.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .accentColor(preferredColor)
                        .font(.body)
                    TextField("Description (optional)", text: $description)
                        .padding(14)
                        .background(Color.secondary.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .accentColor(preferredColor)
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visibility")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 0) {
                        ForEach(["private", "friends"], id: \.self) { option in
                            Button(action: { visibility = option }) {
                                Text(option.capitalized)
                                    .font(.headline)
                                    .foregroundColor(visibility == option ? preferredColor : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        ZStack {
                                            if visibility == option {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white.opacity(0.08))
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(preferredColor.opacity(0.5), lineWidth: 8)
                                                    .blur(radius: 6)
                                                    .offset(x: 0, y: 0)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.5))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("Choose who can see this collection.\nPrivate – Only you can view it.\nFriends – Visible to your active friends.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            Spacer()
            HStack(spacing: 20) {
                Button(action: { onCancel() }) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                Button(action: {
                    onComplete(name, description, visibility)
                }) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    let sampleCollection = Collection(
        id: "test123",
        userId: "user123",
        name: "Test Collection",
        description: "A test collection",
        visibility: "friends",
        createdAt: "2025-01-15T10:30:00Z",
        updatedAt: "2025-01-15T10:30:00Z",
        reviewCount: 5,
        autoSelect: false
    )
    
    EditCollectionView(
        collection: sampleCollection,
        preferredColor: .blue,
        onComplete: { _, _, _ in },
        onCancel: { }
    )
} 