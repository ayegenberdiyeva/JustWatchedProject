import SwiftUI

struct RoomListView: View {
    @StateObject private var viewModel = RoomListViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showCreateRoom = false
    @State private var showInvitations = false
    @State private var pendingInvitationsCount = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !authManager.isAuthenticated {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Please log in to see your rooms")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerSection
                            // Show success message if present
                            if let success = viewModel.successMessage {
                                Text(success)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                                    .transition(.opacity)
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            withAnimation {
                                                viewModel.successMessage = nil
                                            }
                                        }
                                    }
                            }
                            
                            if viewModel.isLoading {
                                                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 40)
                            } else if let error = viewModel.error {
                                errorSection(error: error)
                            } else if viewModel.rooms.isEmpty {
                                emptyStateSection
                            } else {
                                roomsList
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showInvitations = true
                    }) {
                        ZStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.white)
                            if pendingInvitationsCount > 0 {
                                Text("\(pendingInvitationsCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(4)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.isAuthenticated, let jwt = authManager.jwt {
                            Task { await viewModel.fetchRooms(jwt: jwt) }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                if authManager.isAuthenticated, let jwt = authManager.jwt {
                    Task { 
                        await viewModel.fetchRooms(jwt: jwt)
                        await loadPendingInvitationsCount(jwt: jwt)
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated, let jwt = authManager.jwt {
                    Task { 
                        await viewModel.fetchRooms(jwt: jwt)
                        await loadPendingInvitationsCount(jwt: jwt)
                    }
                }
            }
            .background(
                NavigationLink(destination: CreateRoomView { name, description, maxParticipants in
                    if let jwt = authManager.jwt {
                        return await viewModel.createRoom(
                            name: name,
                            description: description,
                            maxParticipants: maxParticipants,
                            jwt: jwt
                        )
                    }
                    return false
                }, isActive: $showCreateRoom) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: RoomInvitationsView(), isActive: $showInvitations) { EmptyView() }
                    .hidden()
            )

        }
    }
    
    private var headerSection: some View {
        ZStack {
            let colorValue = AuthManager.shared.userProfile?.color ?? "red"
            AnimatedPaletteGradientBackground(paletteName: colorValue)
                .cornerRadius(32)
                .overlay(Color.black.opacity(0.5).cornerRadius(32))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Group ")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    Text("Watch")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text("Create or join rooms to choose movies together")
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private func errorSection(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Error loading rooms")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Retry") {
                if authManager.isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRooms(jwt: jwt) }
                }
            }
            .padding()
            .background(Color.white.opacity(0.15))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        // .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No rooms yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Create a room to start watching movies with friends!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Create Room") {
                showCreateRoom = true
            }
            .padding()
            .background(preferredColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        // .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private var roomsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Rooms")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    showCreateRoom = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rooms) { room in
                    NavigationLink(destination: RoomDetailView(roomId: room.roomId)) {
                        RoomCard(
                            room: room,
                            isOwner: viewModel.isOwner(room),
                            isParticipant: viewModel.isParticipant(room),
                            onJoin: {
                                if let jwt = authManager.jwt {
                                    Task { await viewModel.joinRoom(roomId: room.roomId, jwt: jwt) }
                                }
                            },
                            onLeave: {
                                if let jwt = authManager.jwt {
                                    Task { await viewModel.leaveRoom(roomId: room.roomId, jwt: jwt) }
                                }
                            },
                            onDelete: {
                                if let jwt = authManager.jwt {
                                    Task { await viewModel.deleteRoom(roomId: room.roomId, jwt: jwt) }
                                }
                            },
                            viewModel: viewModel
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
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
    
    private func loadPendingInvitationsCount(jwt: String) async {
        do {
            let invitations = try await RoomService().fetchMyInvitations(jwt: jwt)
            let pendingCount = invitations.filter { $0.status == .pending }.count
            await MainActor.run {
                pendingInvitationsCount = pendingCount
            }
        } catch {
            print("Failed to load pending invitations count: \(error)")
        }
    }
}

struct RoomCard: View {
    let room: Room
    let isOwner: Bool
    let isParticipant: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void
    @ObservedObject var viewModel: RoomListViewModel
    @State private var showLeaveConfirmation = false
    @State private var showJoinConfirmation = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(room.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        StatusBadge(status: room.status)

                        Spacer()

                        HStack(spacing: 8) {
                    if isOwner {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            if viewModel.deletingRoomId == room.roomId {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                    .padding(.trailing, 2)
                            } else {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(viewModel.deletingRoomId == room.roomId)
                        .alert("Delete Room", isPresented: $showDeleteConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                onDelete()
                            }
                        } message: {
                            Text("Are you sure you want to delete the room? This action cannot be undone.")
                        }
                    } else if isParticipant {
                        Button(action: {
                            showLeaveConfirmation = true
                        }) {
                            Image(systemName: "figure.walk")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .alert("Leave Room", isPresented: $showLeaveConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Leave", role: .destructive) {
                                onLeave()
                            }
                        } message: {
                            Text("Are you sure you want to leave the room?")
                        }
                    } else {
                        Button(action: {
                            showJoinConfirmation = true
                        }) {
                            Image(systemName: "door.left.hand.closed")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .alert("Join Room", isPresented: $showJoinConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Join") {
                                onJoin()
                            }
                        } message: {
                            Text("Are you sure you want to join the room?")
                        }
                    }
                }
                    }
                    
                    if let description = room.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            
            }
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(room.participants.count) participants")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // HStack(spacing: 8) {
                //     if isOwner {
                //         Button(action: {
                //             showDeleteConfirmation = true
                //         }) {
                //             if viewModel.deletingRoomId == room.roomId {
                //                 ProgressView()
                //                     .tint(.white)
                //                     .scaleEffect(1.5)
                //                     .padding(.trailing, 2)
                //             } else {
                //                 Image(systemName: "trash")
                //                     .font(.body)
                //                     .foregroundColor(.white)
                //             }
                //         }
                //         .disabled(viewModel.deletingRoomId == room.roomId)
                //         .alert("Delete Room", isPresented: $showDeleteConfirmation) {
                //             Button("Cancel", role: .cancel) { }
                //             Button("Delete", role: .destructive) {
                //                 onDelete()
                //             }
                //         } message: {
                //             Text("Are you sure you want to delete the room? This action cannot be undone.")
                //         }
                //     } else if isParticipant {
                //         Button(action: {
                //             showLeaveConfirmation = true
                //         }) {
                //             Image(systemName: "door.left.hand.closed")
                //                 .font(.body)
                //                 .foregroundColor(.white)
                //         }
                //         .alert("Leave Room", isPresented: $showLeaveConfirmation) {
                //             Button("Cancel", role: .cancel) { }
                //             Button("Leave", role: .destructive) {
                //                 onLeave()
                //             }
                //         } message: {
                //             Text("Are you sure you want to leave the room?")
                //         }
                //     } else {
                //         Button(action: {
                //             showJoinConfirmation = true
                //         }) {
                //             Image(systemName: "door.left.hand.closed")
                //                 .font(.body)
                //                 .foregroundColor(.white)
                //         }
                //         .alert("Join Room", isPresented: $showJoinConfirmation) {
                //             Button("Cancel", role: .cancel) { }
                //             Button("Join") {
                //                 onJoin()
                //             }
                //         } message: {
                //             Text("Are you sure you want to join the room?")
                //         }
                //     }
                // }
            }
        }
        .padding()
        .background(Color(hex: "393B3D").opacity(0.3))
        .cornerRadius(16)
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
}

struct StatusBadge: View {
    let status: RoomStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }
    
    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .processing: return .yellow
        case .completed: return .blue
        case .inactive: return .gray
        }
    }
}

#Preview {
    RoomListView()
} 