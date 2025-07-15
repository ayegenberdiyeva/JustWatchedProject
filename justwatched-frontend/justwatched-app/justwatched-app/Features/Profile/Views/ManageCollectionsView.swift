import SwiftUI

struct ManageCollectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var collections: [Collection] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showAddCollection = false
    @State private var showEditCollection = false
    @State private var selectedCollection: Collection? = nil
    
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
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Error loading collections")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadCollections() }
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Manage Collections")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            showAddCollection = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(preferredColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Collections List
                    if collections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No collections yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Create your first collection to organize your reviews!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(collections) { collection in
                                    CollectionRowView(
                                        collection: collection,
                                        preferredColor: preferredColor,
                                        onEdit: {
                                            selectedCollection = collection
                                            showEditCollection = true
                                        },
                                        onDelete: {
                                            print("🗑️ onDelete callback triggered for collection: \(collection.name)")
                                            Task { await deleteCollection(collection) }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddCollection) {
            AddCollectionView(
                preferredColor: preferredColor,
                onComplete: { name, description, visibility in
                    Task {
                        await createCollection(name: name, description: description, visibility: visibility)
                        showAddCollection = false
                    }
                },
                onCancel: { showAddCollection = false }
            )
        }
        .sheet(isPresented: $showEditCollection) {
            if let collection = selectedCollection {
                EditCollectionView(
                    collection: collection,
                    preferredColor: preferredColor,
                    onComplete: { name, description, visibility in
                        Task {
                            await updateCollection(collection, name: name, description: description, visibility: visibility)
                            showEditCollection = false
                            selectedCollection = nil
                        }
                    },
                    onCancel: {
                        showEditCollection = false
                        selectedCollection = nil
                    }
                )
            }
        }
        .task {
            await loadCollections()
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func loadCollections() async {
        isLoading = true
        error = nil
        
        do {
            collections = try await NetworkService.shared.fetchUserCollections()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createCollection(name: String, description: String, visibility: String) async {
        do {
            _ = try await NetworkService.shared.createCollection(name: name, description: description, visibility: visibility)
            await loadCollections()
        } catch {
            print("Error creating collection: \(error)")
        }
    }
    
    private func updateCollection(_ collection: Collection, name: String, description: String, visibility: String) async {
        do {
            _ = try await NetworkService.shared.updateCollection(
                collectionId: collection.id,
                name: name,
                description: description.isEmpty ? nil : description,
                visibility: visibility
            )
            await loadCollections()
        } catch {
            print("Error updating collection: \(error)")
        }
    }
    
    private func deleteCollection(_ collection: Collection) async {
        print("🗑️ Attempting to delete collection: \(collection.id) - \(collection.name)")
        do {
            try await NetworkService.shared.deleteCollection(collectionId: collection.id)
            print("✅ Successfully deleted collection: \(collection.id)")
            await loadCollections()
        } catch {
            print("❌ Error deleting collection \(collection.id): \(error)")
            // Show error to user
            await MainActor.run {
                self.error = "Failed to delete collection: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Collection Row View
struct CollectionRowView: View {
    let collection: Collection
    let preferredColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .foregroundColor(.white)
                if let description = collection.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                HStack {
                    Text("\(collection.reviewCount) reviews")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(collection.visibility.capitalized)
                        .font(.caption)
                        .foregroundColor(collection.visibility == "private" ? .orange : .green)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(preferredColor)
                }
                
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
        .alert("Delete Collection", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { 
                print("❌ Delete cancelled by user")
            }
            Button("Delete", role: .destructive) {
                print("🗑️ User confirmed delete for collection: \(collection.name)")
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(collection.name)'? This action cannot be undone.")
        }
    }
}

#Preview {
    ManageCollectionsView()
} 