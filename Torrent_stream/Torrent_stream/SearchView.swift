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
                response = try await APIService.shared.recent()
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
            self.error = error.localizedDescription
        }
    }

    func search() async {
        mode = .search
        currentPage = 1
        await load()
    }
}

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @State private var selectedTorrent: TorrentItem? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Search torrents...", text: $vm.query)
                                .foregroundColor(.white)
                                .submitLabel(.search)
                                .onSubmit { Task { await vm.search() } }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.1))
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
                        Text("No results").foregroundColor(.gray)
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
            .navigationTitle("TorrentStream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.purple)
                        Text("TorrentStream")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CommunityFeedView()) {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
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
                    .foregroundColor(.white)
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
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
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
