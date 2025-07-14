import SwiftUI

struct ManageCollectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var collections: [Collection] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showAddCollection = false
    
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
                                    CollectionRowView(collection: collection)
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
        .task {
            await loadCollections()
        }
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
}

// MARK: - Collection Row View
struct CollectionRowView: View {
    let collection: Collection
    @State private var showDeleteAlert = false
    
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
            
            Button(action: {
                showDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
        .alert("Delete Collection", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Implement delete collection functionality
                print("Delete collection functionality to be implemented")
            }
        } message: {
            Text("Are you sure you want to delete '\(collection.name)'? This action cannot be undone.")
        }
    }
}

#Preview {
    ManageCollectionsView()
} 