import SwiftUI

struct FriendRequestsView: View {
    @StateObject private var viewModel = FriendsListViewModel()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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
                                Text(req.from_user_id)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Accept") {
                                    Task { await viewModel.respondToRequest(requestId: req.request_id, action: "accept") }
                                }
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.yellow)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                Button("Decline") {
                                    Task { await viewModel.respondToRequest(requestId: req.request_id, action: "decline") }
                                }
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.gray)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
                                Text(req.to_user_id)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Pending")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "FFD600"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                Button(action: {
                                    Task { await viewModel.cancelSentRequest(requestId: req.request_id) }
                                }) {
                                    if viewModel.isLoading {
                                        ProgressView().scaleEffect(0.7)
                                    }
                                    Text("Cancel")
                                }
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.red)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
        .navigationTitle("Friend Requests")
        .onAppear {
            Task { await viewModel.loadPendingRequests() }
        }
    }
} 
