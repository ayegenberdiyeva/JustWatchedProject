import SwiftUI

struct RoomListView: View {
    @StateObject private var viewModel = RoomListViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedRoom: Room? = nil
    @State private var showCreateRoom = false
    
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
                            
                            if viewModel.isLoading {
                                ProgressView("Loading rooms...")
                                    .tint(.white)
                                    .foregroundColor(.white)
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
            .navigationTitle("Group Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
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
                    Task { await viewModel.fetchRooms(jwt: jwt) }
                }
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated, let jwt = authManager.jwt {
                    Task { await viewModel.fetchRooms(jwt: jwt) }
                }
            }
            .sheet(isPresented: $showCreateRoom) {
                CreateRoomView { name, description, maxParticipants in
                    if let jwt = authManager.jwt {
                        Task {
                            let success = await viewModel.createRoom(
                                name: name,
                                description: description,
                                maxParticipants: maxParticipants,
                                jwt: jwt
                            )
                            if success {
                                showCreateRoom = false
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedRoom) { room in
                RoomDetailView(roomId: room.roomId)
            }
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
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Watch")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                Text("Create or join rooms to watch movies together")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .lineLimit(2)
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
        .background(Color(hex: "393B3D").opacity(0.3))
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
        .background(Color(hex: "393B3D").opacity(0.3))
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
                Button("Create Room") {
                    showCreateRoom = true
                }
                .font(.subheadline)
                .foregroundColor(preferredColor)
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rooms) { room in
                    RoomCard(
                        room: room,
                        isOwner: viewModel.isOwner(room),
                        isParticipant: viewModel.isParticipant(room),
                        onTap: { selectedRoom = room },
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
                        }
                    )
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
}

struct RoomCard: View {
    let room: Room
    let isOwner: Bool
    let isParticipant: Bool
    let onTap: () -> Void
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let description = room.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(status: room.status)
                        Text("\(room.currentParticipants)/\(room.maxParticipants)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
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
                    
                    HStack(spacing: 8) {
                        if isOwner {
                            Button("Delete") {
                                onDelete()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if isParticipant {
                            Button("Leave") {
                                onLeave()
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        } else {
                            Button("Join") {
                                onJoin()
                            }
                            .font(.caption)
                            .foregroundColor(preferredColor)
                        }
                    }
                }
            }
            .padding()
            .background(Color(hex: "393B3D").opacity(0.3))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
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
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
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