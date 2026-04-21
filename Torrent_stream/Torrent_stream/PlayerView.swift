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
    @Published var streamStatus: StreamStatus? = nil
    @Published var player: AVPlayer? = nil

    private var pollingTask: Task<Void, Never>? = nil

    deinit {
        pollingTask?.cancel()
    }

    func start(torrent: TorrentItem) async {
        stop()
        phase = .loading
        statusText = "Preparing stream…"

        do {
            // Get streaming URL directly from magnet link
            guard let streamURL = try await APIService.shared.getStreamURL(magnet: torrent.magnet, hash: torrent.hash) else {
                phase = .failed("Could not create stream URL")
                return
            }

            // Create player with the stream URL immediately
            let player = AVPlayer(url: streamURL)
            self.player = player
            self.phase = .playing
            self.statusText = "Streaming: \(torrent.name)"
            player.play()

            // Optional: start polling for progress info to show in UI
            beginPolling(hash: torrent.hash)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        player?.pause()
        player = nil
        streamStatus = nil
        phase = .idle
    }

    private func beginPolling(hash: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    let status = try await APIService.shared.streamStatus(hash: hash)
                    self.streamStatus = status
                    
                    let percent = Int(status.progress * 100)
                    self.statusText = "Buffering… \(percent)% • \(status.num_peers) peers"
                } catch {
                    // Silent fail on polling - don't interrupt playback
                    break
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
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
                        ZStack(alignment: .bottomCenter) {
                            VideoPlayer(player: player)
                                .ignoresSafeArea(edges: .bottom)
                            
                            // Show status info if available
                            if let status = vm.streamStatus {
                                HStack(spacing: 12) {
                                    Image(systemName: "waveform.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(status.num_peers) peers • \(Int(status.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.black.opacity(0.6))
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

            if let status = vm.streamStatus {
                VStack(alignment: .leading, spacing: 8) {
                    statusRow("Peers", "\(status.num_peers)")
                    statusRow("Progress", "\(Int(status.progress * 100))%")
                    statusRow("Down", ByteCountFormatter.string(fromByteCount: Int64(status.download_rate), countStyle: .file) + "/s")
                    statusRow("Up", ByteCountFormatter.string(fromByteCount: Int64(status.upload_rate), countStyle: .file) + "/s")
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
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

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .font(.caption)
    }
}
