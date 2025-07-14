import SwiftUI

struct FriendRequestsView: View {
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var selectedUserId: String? = nil
    @State private var navigateToProfile = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if viewModel.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    // Incoming Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Incoming Friend Requests")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 2)
                        if viewModel.incomingRequests.isEmpty {
                            Text("No incoming friend requests")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.gray)
                        } else {
                            ForEach(viewModel.incomingRequests) { req in
                                HStack(spacing: 16) {
                                    Button(action: {
                                        selectedUserId = req.from_user_id
                                        navigateToProfile = true
                                    }) {
                                        Text(viewModel.userDisplayNames[req.from_user_id] ?? "Loading...")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Button("Accept") {
                                        Task { await viewModel.respondToRequest(requestId: req.request_id, action: "accept") }
                                    }
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 20)
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                                    .buttonStyle(PlainButtonStyle())
                                    Button("Decline") {
                                        Task { await viewModel.respondToRequest(requestId: req.request_id, action: "decline") }
                                    }
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 20)
                                    .background(Color.secondary)
                                    .cornerRadius(12)
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    // Sent Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sent Friend Requests")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 2)
                        if viewModel.sentRequests.isEmpty {
                            Text("No sent friend requests")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.gray)
                        } else {
                            ForEach(viewModel.sentRequests) { req in
                                HStack(spacing: 16) {
                                    Button(action: {
                                        selectedUserId = req.to_user_id
                                        navigateToProfile = true
                                    }) {
                                        Text(viewModel.userDisplayNames[req.to_user_id] ?? "Loading...")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Button(action: {
                                        Task { await viewModel.cancelSentRequest(requestId: req.request_id) }
                                    }) {
                                        if viewModel.isLoading {
                                            ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                                        }
                                        Text("Cancel")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(Color.white)
                                            .cornerRadius(16)
                                    }
                                    .disabled(viewModel.isLoading)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Friend Requests")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToProfile) {
            if let userId = selectedUserId {
                OtherUserProfileView(userId: userId)
            }
        }
        .onAppear {
            Task { await viewModel.loadPendingRequests() }
        }
    }
} 
