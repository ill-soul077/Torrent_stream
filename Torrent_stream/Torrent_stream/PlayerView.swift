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

    func start(torrent: TorrentItem) async {
        stop()
        phase = .loading
        statusText = "Preparing HTTP stream…"
        progressPercent = 0
        peerCount = 0
        downloadRate = 0

        do {
            guard let prepared = try await APIService.shared.prepareStream(magnet: torrent.magnet, hash: torrent.hash) else {
                phase = .failed("Unable to prepare stream")
                return
            }

            selectedVideoName = prepared.payload.selected_video?.name
            subtitleTracks = prepared.payload.subtitle_tracks ?? []

            if let selectedVideoName {
                if subtitleTracks.isEmpty {
                    statusText = "Streaming: \(selectedVideoName) • no subtitles found"
                } else {
                    statusText = "Streaming: \(selectedVideoName) • subtitles: \(subtitleTracks.count)"
                }
            } else {
                statusText = prepared.payload.message
            }

            let player = AVPlayer(url: prepared.url)
            player.automaticallyWaitsToMinimizeStalling = true
            self.player = player
            self.phase = .playing
            player.play()
        } catch let apiError as APIError {
            phase = .failed(apiError.localizedDescription)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        player?.pause()
        player = nil
        progressPercent = 0
        peerCount = 0
        downloadRate = 0
        selectedVideoName = nil
        subtitleTracks = []
        phase = .idle
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
