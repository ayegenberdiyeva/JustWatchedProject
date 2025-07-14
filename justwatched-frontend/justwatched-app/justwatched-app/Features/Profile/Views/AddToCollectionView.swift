import SwiftUI

struct AddToCollectionView: View {
    let review: Review
    let collections: [Collection]
    @Binding var selectedCollections: Set<String>
    let preferredColor: Color
    var onComplete: (Set<String>) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Add to Collections")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Review Preview
                HStack(spacing: 12) {
                    if let posterPath = review.posterPath {
                        AsyncImage(url: posterPath.posterURL(size: "w92")) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(review.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text("Rating: \(review.rating)/5")
                            .font(.subheadline)
                            .foregroundColor(preferredColor)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(hex: "393B3D").opacity(0.3))
                .cornerRadius(16)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)
            .padding(.horizontal, 24)
            
            Divider().background(Color.white.opacity(0.12))
            
            // Collections List
            if collections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No collections yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Create a collection first to organize your reviews!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(collections) { collection in
                            CollectionSelectionRow(
                                collection: collection,
                                isSelected: selectedCollections.contains(collection.id),
                                preferredColor: preferredColor,
                                onToggle: {
                                    if selectedCollections.contains(collection.id) {
                                        selectedCollections.remove(collection.id)
                                    } else {
                                        selectedCollections.insert(collection.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            
            // Action Buttons
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
                    onComplete(selectedCollections)
                }) {
                    Text("Add to Selected")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedCollections.isEmpty ? Color.gray : preferredColor)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                .disabled(selectedCollections.isEmpty)
                .opacity(selectedCollections.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Collection Selection Row
struct CollectionSelectionRow: View {
    let collection: Collection
    let isSelected: Bool
    let preferredColor: Color
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
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
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? preferredColor : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? preferredColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    let sampleReview = Review(
        id: "review123",
        mediaId: "12345",
        mediaType: "movie",
        title: "Sample Movie",
        rating: 4,
        content: "This is a great movie!",
        posterPath: "/sample-poster.jpg",
        status: "watched",
        watchedDate: Date(),
        createdAt: Date(),
        updatedAt: Date()
    )
    
    let sampleCollections = [
        Collection(
            id: "coll1",
            userId: "user123",
            name: "Action Movies",
            description: "High-octane action films",
            visibility: "friends",
            createdAt: "2025-01-15T10:30:00Z",
            updatedAt: "2025-01-15T10:30:00Z",
            reviewCount: 5,
            autoSelect: false
        ),
        Collection(
            id: "coll2",
            userId: "user123",
            name: "Private Collection",
            description: "My private thoughts",
            visibility: "private",
            createdAt: "2025-01-16T14:20:00Z",
            updatedAt: "2025-01-16T14:20:00Z",
            reviewCount: 2,
            autoSelect: false
        )
    ]
    
    AddToCollectionView(
        review: sampleReview,
        collections: sampleCollections,
        selectedCollections: .constant(Set()),
        preferredColor: .blue,
        onComplete: { _ in },
        onCancel: { }
    )
} 