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
    @Published var selectedVideoName: String? = nil
    @Published var subtitleTracks: [StreamSubtitleTrack] = []
    @Published var player: AVPlayer? = nil

    func start(torrent: TorrentItem) async {
        stop()
        phase = .loading
        statusText = "Preparing stream on server…"

        do {
            guard let prepared = try await APIService.shared.prepareStream(magnet: torrent.magnet, hash: torrent.hash) else {
                phase = .failed("Could not prepare stream from backend response.")
                return
            }

            selectedVideoName = prepared.payload.selected_video?.name
            subtitleTracks = prepared.payload.subtitle_tracks ?? []

            if prepared.payload.prepared == false {
                statusText = "Server is still loading torrent metadata… starting playback when ready"
            }

            let player = AVPlayer(url: prepared.url)
            player.automaticallyWaitsToMinimizeStalling = true
            self.player = player
            self.phase = .playing
            if subtitleTracks.isEmpty {
                self.statusText = "Streaming: \(torrent.name) • no subtitles found"
            } else {
                self.statusText = "Streaming: \(torrent.name) • subtitles: \(subtitleTracks.count)"
            }
            player.play()
        } catch let urlError as URLError where urlError.code == .timedOut {
            phase = .failed("Prepare request timed out. Server is still fetching metadata/peers. Try again in a few seconds.")
        } catch let apiError as APIError {
            phase = .failed(apiError.localizedDescription)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        player?.pause()
        player = nil
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
