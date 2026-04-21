import SwiftUI

struct TorrentDetailView: View {
    let torrent: TorrentItem
    @Environment(\.dismiss) var dismiss
    @State private var showPlayer = false
    @State private var showAddToPlaylist = false
    @State private var showCommunityComposer = false
    @State private var toast: String? = nil

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        AsyncImage(url: URL(string: torrent.poster)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(Image(systemName: "film").font(.system(size: 60)).foregroundColor(.gray))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                        .overlay(LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom))

                        VStack(alignment: .leading, spacing: 16) {
                            Text(torrent.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            HStack(spacing: 16) {
                                statBadge("↑ \(torrent.seeders)", color: .green)
                                statBadge("↓ \(torrent.leechers)", color: .red)
                                if !torrent.size.isEmpty {
                                    statBadge(torrent.size, color: .blue)
                                }
                                if !torrent.category.isEmpty {
                                    statBadge(torrent.category, color: .purple)
                                }
                            }

                            if let files = torrent.files, !files.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Files").font(.subheadline).foregroundColor(.gray)
                                    ForEach(files, id: \.self) { file in
                                        Text("• \(file)").font(.caption).foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }

                            if let shots = torrent.screenshot, !shots.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Screenshots").font(.subheadline).foregroundColor(.gray)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(shots.prefix(6), id: \.self) { url in
                                                AsyncImage(url: URL(string: url)) { img in
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Color.white.opacity(0.1)
                                                }
                                                .frame(width: 140, height: 80)
                                                .cornerRadius(8)
                                                .clipped()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 120)
                    }
                }
                .background(Color.black)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    HStack(spacing: 12) {
                        Button(action: { showPlayer = true }) {
                            Label("Play", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(12)
                        }

                        listButton("clock.fill", "Later") { addTo("watchlater") }
                        listButton("plus", "Playlist") { showAddToPlaylist = true }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.9))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") { showCommunityComposer = true }
                        .foregroundColor(.purple)
                }
            }
        }
        .overlay(
            Group {
                if let message = toast {
                    ToastView(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
        .sheet(isPresented: $showPlayer) {
            PlayerView(torrent: torrent)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(torrent: torrent)
        }
        .sheet(isPresented: $showCommunityComposer) {
            CommunityPostComposerView(torrent: torrent) { message in
                showToast(message)
            }
        }
    }

    func addTo(_ list: String) {
        Task {
            do {
                switch list {
                case "watchlater":
                    try await APIService.shared.addWatchLater(torrent)
                default:
                    break
                }
                showToast("Added to \(list.capitalized) ✓")
            } catch {
                showToast("Error: \(error.localizedDescription)")
            }
        }
    }

    func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }

    @ViewBuilder
    func statBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }

    @ViewBuilder
    func listButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 14))
                Text(label).font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 52, height: 48)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.top, 60)
    }
}

struct AddToPlaylistSheet: View {
    let torrent: TorrentItem
    @State private var playlists: [Playlist] = []
    @State private var newName = ""
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Add to existing") {
                    if playlists.isEmpty && !isLoading {
                        Text("No playlists yet").foregroundColor(.gray)
                    }
                    ForEach(playlists) { playlist in
                        Button(playlist.name) {
                            Task {
                                try? await APIService.shared.addToPlaylist(playlistId: playlist.id, torrent: torrent)
                                dismiss()
                            }
                        }
                    }
                }
                Section("Create new playlist") {
                    TextField("Playlist name", text: $newName)
                    Button("Create & Add") {
                        Task {
                            if let playlist = try? await APIService.shared.createPlaylist(name: newName) {
                                try? await APIService.shared.addToPlaylist(playlistId: playlist.id, torrent: torrent)
                            }
                            dismiss()
                        }
                    }
                    .disabled(newName.isEmpty)
                }
            }
            .navigationTitle("Add to Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                playlists = (try? await APIService.shared.getPlaylists()) ?? []
                isLoading = false
            }
        }
    }
}
