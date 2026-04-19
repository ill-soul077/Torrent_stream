import SwiftUI
import AVKit

@MainActor
final class PlayerViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case waitingForMetadata
        case choosingFile
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var statusText = "Preparing torrent…"
    @Published var selectedFile: TorrentFile? = nil
    @Published var availableFiles: [TorrentFile] = []
    @Published var streamStatus: StreamStatus? = nil
    @Published var player: AVPlayer? = nil

    private var pollingTask: Task<Void, Never>? = nil

    deinit {
        pollingTask?.cancel()
    }

    func start(torrent: TorrentItem) async {
        stop()
        phase = .preparing
        statusText = "Sending magnet link to server…"

        do {
            _ = try await APIService.shared.startMagnetSession(magnet: torrent.magnet, hash: torrent.hash)
            phase = .waitingForMetadata
            statusText = "Fetching torrent metadata…"
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
        availableFiles = []
        selectedFile = nil
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

                    if status.has_metadata {
                        self.phase = .choosingFile
                        self.statusText = "Looking for playable video file…"

                        let files = try await APIService.shared.torrentFiles(hash: hash)
                        self.availableFiles = files

                        guard let bestFile = APIService.shared.bestPlayableVideo(from: files) else {
                            self.phase = .failed("No playable video file found in torrent.")
                            return
                        }

                        guard let url = APIService.shared.streamFileURL(hash: hash, fileIndex: bestFile.index) else {
                            self.phase = .failed("Could not build file stream URL.")
                            return
                        }

                        self.selectedFile = bestFile
                        self.player = AVPlayer(url: url)
                        self.phase = .ready
                        self.statusText = "Streaming \(bestFile.displayName)"
                        self.player?.play()
                        return
                    } else {
                        let percent = Int(status.progress * 100)
                        self.phase = .waitingForMetadata
                        self.statusText = "Waiting for metadata… \(percent)% • peers \(status.num_peers)"
                    }
                } catch {
                    self.phase = .failed(error.localizedDescription)
                    return
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
                case .ready:
                    if let player = vm.player {
                        VideoPlayer(player: player)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        progressBody
                    }

                case .failed(let message):
                    failureBody(message)

                default:
                    progressBody
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

    private var progressBody: some View {
        VStack(spacing: 18) {
            ProgressView().tint(.purple)

            Text(vm.statusText)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let status = vm.streamStatus {
                VStack(alignment: .leading, spacing: 8) {
                    statusRow("State", status.state)
                    statusRow("Peers", "\(status.num_peers)")
                    statusRow("Progress", "\(Int(status.progress * 100))%")
                    statusRow("Down", ByteCountFormatter.string(fromByteCount: Int64(status.download_rate), countStyle: .file) + "/s")
                    statusRow("Up", ByteCountFormatter.string(fromByteCount: Int64(status.upload_rate), countStyle: .file) + "/s")
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }

            if !vm.availableFiles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected files")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(vm.availableFiles.prefix(8)) { file in
                        HStack {
                            Image(systemName: file.isPlayableVideo ? "film.fill" : "doc.fill")
                                .foregroundColor(file.isPlayableVideo ? .green : .gray)
                            Text(file.displayName)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
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
