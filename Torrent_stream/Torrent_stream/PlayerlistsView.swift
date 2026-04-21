import SwiftUI

@MainActor
class PlaylistsVM: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        do { playlists = try await APIService.shared.getPlaylists() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func create(name: String, description: String) async {
        do {
            let pl = try await APIService.shared.createPlaylist(name: name, description: description)
            playlists.append(pl)
        } catch { self.error = error.localizedDescription }
    }

    func delete(_ id: Int) async {
        do {
            try await APIService.shared.deletePlaylist(id)
            playlists.removeAll { $0.id == id }
        } catch { self.error = error.localizedDescription }
    }
}

struct PlaylistsView: View {
    @StateObject private var vm = PlaylistsVM()
    @State private var showCreate = false
    @State private var selectedPlaylist: Playlist? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView().tint(.purple)
                } else if vm.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.below.rectangle")
                            .font(.system(size: 48)).foregroundColor(.purple.opacity(0.4))
                        Text("No playlists yet")
                            .font(.headline).foregroundColor(.gray)
                        Button("Create Playlist") { showCreate = true }
                            .buttonStyle(.bordered).tint(.purple)
                    }
                } else {
                    List {
                        ForEach(vm.playlists) { pl in
                            Button(action: { selectedPlaylist = pl }) {
                                PlaylistRow(playlist: pl)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.delete(pl.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus")
                    }
                    .tint(.purple)
                }
            }
            .sheet(isPresented: $showCreate) {
                CreatePlaylistSheet { name, desc in
                    await vm.create(name: name, description: desc)
                }
            }
            .sheet(item: $selectedPlaylist) { pl in
                PlaylistDetailView(playlist: pl)
            }
        }
        .navigationViewStyle(.stack)
        .task { await vm.load() }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [.purple, .blue],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "list.bullet.below.rectangle")
                    .foregroundColor(.white).font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                if !playlist.description.isEmpty {
                    Text(playlist.description)
                        .font(.caption).foregroundColor(.gray).lineLimit(1)
                }
                Text("\(playlist.item_count ?? 0) items")
                    .font(.caption2).foregroundColor(.purple)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Create Playlist Sheet
struct CreatePlaylistSheet: View {
    var onSave: (String, String) async -> Void
    @State private var name = ""
    @State private var description = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Playlist name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
            }
            .navigationTitle("New Playlist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await onSave(name, description)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Playlist Detail
@MainActor
class PlaylistDetailVM: ObservableObject {
    @Published var detail: PlaylistDetail? = nil
    @Published var isLoading = false

    func load(_ id: Int) async {
        isLoading = true
        detail = try? await APIService.shared.getPlaylist(id)
        isLoading = false
    }

    func removeItem(playlistId: Int, itemId: Int) async {
        try? await APIService.shared.removeFromPlaylist(playlistId: playlistId, itemId: itemId)
        await load(playlistId)
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist
    @StateObject private var vm = PlaylistDetailVM()
    @State private var nowPlayingIndex: Int? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView().tint(.purple)
                } else if let d = vm.detail {
                    if d.items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48)).foregroundColor(.gray)
                            Text("Playlist is empty").foregroundColor(.gray)
                        }
                    } else {
                        List {
                            // Play all button
                            Button(action: { nowPlayingIndex = 0 }) {
                                Label("Play All", systemImage: "play.fill")
                                    .font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(colors: [.purple, .blue],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(12)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                            ForEach(Array(d.items.enumerated()), id: \.element.id) { idx, item in
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.caption).foregroundColor(.gray)
                                        .frame(width: 20)

                                    AsyncImage(url: URL(string: item.torrent.poster)) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.white.opacity(0.08)
                                    }
                                    .frame(width: 44, height: 60)
                                    .cornerRadius(6)
                                    .clipped()

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.torrent.name)
                                            .font(.caption).foregroundColor(.white).lineLimit(2)
                                        Text(item.torrent.size).font(.caption2).foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Button(action: { nowPlayingIndex = idx }) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title3).foregroundColor(.purple)
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.removeItem(playlistId: d.id, itemId: item.id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(playlist.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { nowPlayingIndex.map { PlayingIndex(index: $0) } },
                set: { nowPlayingIndex = $0?.index }
            )) { pi in
                if let items = vm.detail?.items, pi.index < items.count {
                    PlayerView(torrent: items[pi.index].torrent.toTorrentItem())
                }
            }
        }
        .task { await vm.load(playlist.id) }
    }
}

struct PlayingIndex: Identifiable {
    let id = UUID()
    let index: Int
}
