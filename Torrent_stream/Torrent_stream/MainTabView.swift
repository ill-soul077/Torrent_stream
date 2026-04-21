import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(0)

            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "eye.fill")
                }
                .tag(1)

            WatchLaterView()
                .tabItem {
                    Label("Watch Later", systemImage: "clock.fill")
                }
                .tag(2)

            CommunityFeedView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .tag(3)

            PlaylistsView()
                .tabItem {
                    Label("Playlists", systemImage: "list.bullet.below.rectangle")
                }
                .tag(4)
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
    }
}
