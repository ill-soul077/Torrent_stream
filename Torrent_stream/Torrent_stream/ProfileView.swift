import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showServerConfig = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(auth.email.isEmpty ? "Signed in" : auth.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.white.opacity(0.05))

            Section("Browse") {
                NavigationLink(destination: WatchlistView()) {
                    profileRow("Watchlist", systemImage: "eye.fill", color: .blue)
                }
                NavigationLink(destination: WatchLaterView()) {
                    profileRow("Watch Later", systemImage: "clock.fill", color: .orange)
                }
                NavigationLink(destination: PlaylistsView()) {
                    profileRow("Playlists", systemImage: "list.bullet.below.rectangle", color: .purple)
                }
                NavigationLink(destination: CommunityFeedView()) {
                    profileRow("Community", systemImage: "person.3.fill", color: .green)
                }
            }
            .listRowBackground(Color.white.opacity(0.05))

            Section("Account") {
                Button(action: { showServerConfig = true }) {
                    profileRow("Server Settings", systemImage: "server.rack", color: .gray)
                }
                Button(role: .destructive, action: auth.logout) {
                    profileRow("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", color: .red)
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet().environmentObject(auth)
        }
    }

    @ViewBuilder
    private func profileRow(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .foregroundColor(.white)
            Spacer()
        }
    }
}
