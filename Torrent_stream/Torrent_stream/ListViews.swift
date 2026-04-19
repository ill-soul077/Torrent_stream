import SwiftUI

struct UserListView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let items: [ListItem]
    let isLoading: Bool
    let error: String?
    let onRefresh: () async -> Void
    let onDelete: (String) async -> Void
    let rowExtra: (ListItem) -> Content

    init(
        title: String,
        icon: String,
        color: Color,
        items: [ListItem],
        isLoading: Bool,
        error: String?,
        onRefresh: @escaping () async -> Void,
        onDelete: @escaping (String) async -> Void,
        @ViewBuilder rowExtra: @escaping (ListItem) -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.items = items
        self.isLoading = isLoading
        self.error = error
        self.onRefresh = onRefresh
        self.onDelete = onDelete
        self.rowExtra = rowExtra
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(color)
                } else if let err = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(err)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.4))
                        Text("Your \(title) is empty")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Search for torrents and add them here")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            ListItemRow(item: item, accentColor: color) {
                                rowExtra(item)
                            }
                                .listRowBackground(Color.white.opacity(0.05))
                                .listRowSeparatorTint(Color.white.opacity(0.08))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await onDelete(item.list_id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await onRefresh() }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .task { await onRefresh() }
    }
}

struct ListItemRow<Extra: View>: View {
    let item: ListItem
    let accentColor: Color
    let extra: () -> Extra
    @State private var showPlayer = false

    init(
        item: ListItem,
        accentColor: Color,
        @ViewBuilder extra: @escaping () -> Extra
    ) {
        self.item = item
        self.accentColor = accentColor
        self.extra = extra
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.torrent.poster)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.white.opacity(0.08)
                    .overlay(Image(systemName: "film").foregroundColor(.gray))
            }
            .frame(width: 52, height: 70)
            .cornerRadius(8)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.torrent.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !item.torrent.size.isEmpty {
                        Text(item.torrent.size).font(.caption2).foregroundColor(.gray)
                    }
                    if !item.torrent.category.isEmpty {
                        Text(item.torrent.category)
                            .font(.caption2)
                            .foregroundColor(accentColor)
                    }
                }

                extra()
            }

            Spacer()

            Button(action: { showPlayer = true }) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(accentColor)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showPlayer) {
            PlayerView(torrent: item.torrent.toTorrentItem())
        }
    }
}

@MainActor
final class WatchlistVM: ObservableObject {
    @Published var items: [ListItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            items = try await APIService.shared.getWatchlist()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func remove(_ id: String) async {
        do {
            try await APIService.shared.removeWatchlist(id)
            items.removeAll { $0.list_id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleWatched(_ item: ListItem) async {
        let newValue = !(item.watched ?? false)
        do {
            try await APIService.shared.markWatched(item.list_id, watched: newValue)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct WatchlistView: View {
    @StateObject private var vm = WatchlistVM()

    var body: some View {
        UserListView(
            title: "Watchlist",
            icon: "eye.fill",
            color: .blue,
            items: vm.items,
            isLoading: vm.isLoading,
            error: vm.error,
            onRefresh: { await vm.load() },
            onDelete: { await vm.remove($0) }
        ) { item in
            Button(action: { Task { await vm.toggleWatched(item) } }) {
                HStack(spacing: 4) {
                    Image(systemName: item.watched == true ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(item.watched == true ? .green : .gray)
                    Text(item.watched == true ? "Watched" : "Mark Watched")
                        .font(.caption2)
                        .foregroundColor(item.watched == true ? .green : .gray)
                }
            }
        }
    }
}

@MainActor
final class WishlistVM: ObservableObject {
    @Published var items: [ListItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            items = try await APIService.shared.getWishlist()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func remove(_ id: String) async {
        do {
            try await APIService.shared.removeWishlist(id)
            items.removeAll { $0.list_id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct WishlistView: View {
    @StateObject private var vm = WishlistVM()

    var body: some View {
        UserListView(
            title: "Wishlist",
            icon: "heart.fill",
            color: .pink,
            items: vm.items,
            isLoading: vm.isLoading,
            error: vm.error,
            onRefresh: { await vm.load() },
            onDelete: { await vm.remove($0) }
        ) { _ in EmptyView() }
    }
}

@MainActor
final class WatchLaterVM: ObservableObject {
    @Published var items: [ListItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            items = try await APIService.shared.getWatchLater()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func remove(_ id: String) async {
        do {
            try await APIService.shared.removeWatchLater(id)
            items.removeAll { $0.list_id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct WatchLaterView: View {
    @StateObject private var vm = WatchLaterVM()

    var body: some View {
        UserListView(
            title: "Watch Later",
            icon: "clock.fill",
            color: .orange,
            items: vm.items,
            isLoading: vm.isLoading,
            error: vm.error,
            onRefresh: { await vm.load() },
            onDelete: { await vm.remove($0) }
        ) { _ in EmptyView() }
    }
}
