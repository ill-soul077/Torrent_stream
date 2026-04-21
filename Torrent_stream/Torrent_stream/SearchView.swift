import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    enum SearchMode { case trending, recent, search }

    @Published var results: [TorrentItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var query = ""
    @Published var selectedCategory = "all"
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var mode: SearchMode = .trending

    let categories = ["all", "movies", "tv", "4k", "music", "games", "apps", "audio", "video", "other"]

    var modeSummary: String {
        switch mode {
        case .trending:
            return "Trending is based on the server's most-used items."
        case .recent:
            return "Recent keeps your personal viewing and search history."
        case .search:
            return "Search results are filtered for blocked terms and sites."
        }
    }

    var emptyStateText: String {
        switch mode {
        case .trending:
            return "No trending items yet"
        case .recent:
            return "No recent history yet"
        case .search:
            return "No results"
        }
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: SearchResponse
            switch mode {
            case .trending:
                response = try await APIService.shared.trending(category: selectedCategory == "4k" ? "video" : selectedCategory)
                totalPages = 1
            case .recent:
                response = try await APIService.shared.recent(category: selectedCategory == "4k" ? "video" : selectedCategory)
                totalPages = 1
            case .search:
                guard !query.isEmpty else {
                    results = []
                    totalPages = 1
                    return
                }
                response = try await APIService.shared.search(query: query, category: selectedCategory)
                totalPages = response.total_pages ?? 1
            }
            results = response.data
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("blocked content") {
                self.error = "That search is blocked by the server safety filter."
            } else {
                self.error = message
            }
        }
    }

    func search() async {
        mode = .search
        currentPage = 1
        await load()
    }
}

struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = SearchViewModel()
    @State private var selectedTorrent: TorrentItem? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AppPalette.background(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Search torrents...", text: $vm.query)
                                .foregroundColor(AppPalette.primaryText(for: colorScheme))
                                .submitLabel(.search)
                                .onSubmit { Task { await vm.search() } }
                        }
                        .padding(10)
                        .background(AppPalette.subtleFill(for: colorScheme))
                        .cornerRadius(12)

                        Menu {
                            ForEach(vm.categories, id: \.self) { category in
                                Button(category.capitalized) {
                                    vm.selectedCategory = category
                                    Task { await vm.load() }
                                }
                            }
                        } label: {
                            Text(vm.selectedCategory.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    HStack(spacing: 0) {
                        modeButton("Trending", mode: .trending, icon: "flame.fill")
                        modeButton("Recent", mode: .recent, icon: "clock.fill")
                        if !vm.query.isEmpty {
                            modeButton("Results", mode: .search, icon: "magnifyingglass")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    Text(vm.modeSummary)
                        .font(.caption)
                        .foregroundColor(AppPalette.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(.purple)
                        Spacer()
                    } else if let err = vm.error {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(err)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else if vm.results.isEmpty {
                        Spacer()
                        Text(vm.emptyStateText).foregroundColor(AppPalette.secondaryText(for: colorScheme))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.results) { torrent in
                                    TorrentCard(torrent: torrent)
                                        .onTapGesture { selectedTorrent = torrent }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .appHeader("TorrentStream")
            .sheet(item: $selectedTorrent) { torrent in
                TorrentDetailView(torrent: torrent)
            }
            .task { await vm.load() }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    func modeButton(_ title: String, mode: SearchViewModel.SearchMode, icon: String) -> some View {
        Button(action: {
            vm.mode = mode
            Task { await vm.load() }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(vm.mode == mode ? Color.purple : Color.white.opacity(0.08))
            .cornerRadius(20)
            .foregroundColor(vm.mode == mode ? .white : .gray)
        }
        .padding(.trailing, 6)
    }
}

struct TorrentCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let torrent: TorrentItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: torrent.poster)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(Image(systemName: "film").foregroundColor(.gray))
            }
            .frame(width: 60, height: 80)
            .cornerRadius(8)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppPalette.primaryText(for: colorScheme))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !torrent.category.isEmpty {
                        tagView(torrent.category, color: .blue)
                    }
                    if !torrent.size.isEmpty {
                        tagView(torrent.size, color: .gray)
                    }
                }

                HStack(spacing: 12) {
                    seedLeechBadge(icon: "arrow.up.circle.fill", value: torrent.seeders, color: .green)
                    seedLeechBadge(icon: "arrow.down.circle.fill", value: torrent.leechers, color: .red)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
        }
        .padding(12)
        .background(AppPalette.cardBackground(for: colorScheme))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppPalette.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    func tagView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    @ViewBuilder
    func seedLeechBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundColor(color)
            Text(value).font(.caption2).foregroundColor(.gray)
        }
    }
}
