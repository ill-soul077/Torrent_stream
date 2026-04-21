import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showServerConfig = false
    @AppStorage("appTheme") private var appTheme = AppThemePreference.dark.rawValue

    private var theme: AppThemePreference {
        AppThemePreference(rawValue: appTheme) ?? .dark
    }

    private var themeButtonTitle: String {
        theme == .dark ? "Switch to Light Theme" : "Switch to Dark Theme"
    }

    private var themeButtonIcon: String {
        theme == .dark ? "sun.max.fill" : "moon.fill"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                        .font(.headline)
                        .foregroundColor(AppPalette.primaryText(for: colorScheme))
                    Text(auth.email.isEmpty ? "Signed in" : auth.email)
                        .font(.subheadline)
                        .foregroundColor(AppPalette.secondaryText(for: colorScheme))
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(AppPalette.cardBackground(for: colorScheme))

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
            .listRowBackground(AppPalette.cardBackground(for: colorScheme))

            Section("Account") {
                Button(action: toggleTheme) {
                    profileRow(themeButtonTitle, systemImage: themeButtonIcon, color: .purple)
                }
                Button(action: { showServerConfig = true }) {
                    profileRow("Server Settings", systemImage: "server.rack", color: .gray)
                }
                Button(role: .destructive, action: auth.logout) {
                    profileRow("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", color: .red)
                }
            }
            .listRowBackground(AppPalette.cardBackground(for: colorScheme))
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.background(for: colorScheme).ignoresSafeArea())
        .appHeader("TorrentStream", showProfileLink: false)
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet().environmentObject(auth)
        }
        .animation(.easeInOut(duration: 0.3), value: appTheme)
    }

    @ViewBuilder
    private func profileRow(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .foregroundColor(AppPalette.primaryText(for: colorScheme))
            Spacer()
        }
    }

    private func toggleTheme() {
        var nextTheme = theme
        nextTheme.toggle()
        appTheme = nextTheme.rawValue
    }
}
