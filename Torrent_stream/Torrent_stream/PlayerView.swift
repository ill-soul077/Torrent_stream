import SwiftUI
import AVKit

@MainActor
final class PlayerViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case playing
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var statusText = "Starting playback…"
    @Published var progressPercent: Int = 0
    @Published var peerCount: Int = 0
    @Published var downloadRate: Int = 0
    @Published var selectedVideoName: String? = nil
    @Published var subtitleTracks: [StreamSubtitleTrack] = []
    @Published var player: AVPlayer? = nil

    private var socketTask: URLSessionWebSocketTask? = nil
    private var socketListenTask: Task<Void, Never>? = nil

    func start(torrent: TorrentItem) async {
        stop()
        phase = .loading
        statusText = "Connecting to torrent session…"

        do {
            let socket = try APIService.shared.openStreamSocket(magnet: torrent.magnet, hash: torrent.hash)
            socketTask = socket
            statusText = "Fetching nodes and metadata…"

            socketListenTask = Task { [weak self] in
                await self?.listenToSocket(socket, torrentName: torrent.name)
            }
        } catch let apiError as APIError {
            phase = .failed(apiError.localizedDescription)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        socketListenTask?.cancel()
        socketListenTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil

        player?.pause()
        player = nil
        progressPercent = 0
        peerCount = 0
        downloadRate = 0
        selectedVideoName = nil
        subtitleTracks = []
        phase = .idle
    }

    private func listenToSocket(_ socket: URLSessionWebSocketTask, torrentName: String) async {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let raw):
                    data = raw
                @unknown default:
                    continue
                }

                let event = try JSONDecoder().decode(StreamSocketEvent.self, from: data)
                handleSocketEvent(event, socket: socket, torrentName: torrentName)
            } catch {
                if Task.isCancelled {
                    return
                }

                phase = .failed("Stream socket disconnected: \(error.localizedDescription)")
                return
            }
        }
    }

    private func handleSocketEvent(_ event: StreamSocketEvent, socket: URLSessionWebSocketTask, torrentName: String) {
        switch event.type {
        case "started":
            statusText = event.message ?? "Torrent session started."

        case "status":
            let progress = max(0.0, min(1.0, event.progress ?? 0.0))
            progressPercent = Int(progress * 100)
            peerCount = max(0, event.num_peers ?? 0)
            downloadRate = max(0, event.download_rate ?? 0)

            if event.has_metadata == true {
                statusText = "Metadata fetched. Preparing stream…"
            } else {
                statusText = "Fetching nodes… \(progressPercent)% • peers \(peerCount)"
            }

        case "ready":
            guard let streamURLString = event.stream_url, let streamURL = URL(string: streamURLString) else {
                phase = .failed("Ready event missing valid stream URL")
                return
            }

            selectedVideoName = event.selected_video?.name
            subtitleTracks = event.subtitle_tracks ?? []

            let player = AVPlayer(url: streamURL)
            player.automaticallyWaitsToMinimizeStalling = true
            self.player = player
            self.phase = .playing

            if subtitleTracks.isEmpty {
                statusText = "Streaming: \(torrentName) • no subtitles found"
            } else {
                statusText = "Streaming: \(torrentName) • subtitles: \(subtitleTracks.count)"
            }

            player.play()
            socket.cancel(with: .normalClosure, reason: nil)
            socketTask = nil

        case "error":
            phase = .failed(event.message ?? "Stream preparation failed")

        default:
            if let message = event.message, !message.isEmpty {
                statusText = message
            }
        }
    }
}

struct PlayerView: View {
    let torrent: TorrentItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PlayerViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                switch vm.phase {
                case .playing:
                    if let player = vm.player {
                        ZStack(alignment: .bottom) {
                            VideoPlayer(player: player)
                                .ignoresSafeArea(edges: .bottom)

                            if vm.selectedVideoName != nil || !vm.subtitleTracks.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let selected = vm.selectedVideoName {
                                        Text("Video: \(selected)")
                                            .lineLimit(1)
                                    }
                                    Text(vm.subtitleTracks.isEmpty ? "Subtitles: none" : "Subtitles: \(vm.subtitleTracks.count)")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.65))
                                .cornerRadius(10)
                                .padding(.bottom, 14)
                                .padding(.horizontal, 12)
                            }
                        }
                    } else {
                        loadingBody
                    }

                case .loading:
                    loadingBody

                case .failed(let message):
                    failureBody(message)

                case .idle:
                    loadingBody
                }
            }
            .navigationTitle(torrent.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        vm.stop()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await vm.start(torrent: torrent)
        }
        .onDisappear {
            vm.stop()
        }
    }

    private var loadingBody: some View {
        VStack(spacing: 18) {
            ProgressView().tint(.purple)

            Text(vm.statusText)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .font(.headline)

            if vm.phase == .loading {
                VStack(spacing: 6) {
                    Text("Progress: \(vm.progressPercent)%")
                    Text("Peers: \(vm.peerCount)")
                    Text("Download: \(ByteCountFormatter.string(fromByteCount: Int64(vm.downloadRate), countStyle: .file))/s")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
    }

    private func failureBody(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)

            Text("Playback failed")
                .font(.headline)
                .foregroundColor(.white)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
    }

}
