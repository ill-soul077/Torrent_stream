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
    @Published var playbackModeLabel: String? = nil

    private var streamTask: Task<Void, Never>?
    private var streamSocket: URLSessionWebSocketTask?
    private var playerItemObservation: NSKeyValueObservation?
    private var playerTimeControlObservation: NSKeyValueObservation?
    private var playerFailureObserver: NSObjectProtocol?
    private var playerStallObserver: NSObjectProtocol?
    private var pendingFallbackURL: URL?
    private var pendingFallbackMode: String?
    private var currentPlaybackURL: URL?
    private var currentPlaybackMode: String?
    private var isSwitchingPlayback = false
    private var playbackStartupTask: Task<Void, Never>?

    func start(torrent: TorrentItem) {
        stop()
        phase = .loading
        statusText = "Preparing stream…"
        progressPercent = 0
        peerCount = 0
        downloadRate = 0
        playbackModeLabel = nil

        streamTask = Task { [weak self] in
            await self?.runStreamSession(torrent: torrent)
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        streamSocket?.cancel(with: .goingAway, reason: nil)
        streamSocket = nil
        playerItemObservation = nil
        playerTimeControlObservation = nil
        playbackStartupTask?.cancel()
        playbackStartupTask = nil
        removePlayerObservers()
        player?.pause()
        player = nil
        pendingFallbackURL = nil
        pendingFallbackMode = nil
        currentPlaybackURL = nil
        currentPlaybackMode = nil
        isSwitchingPlayback = false
        progressPercent = 0
        peerCount = 0
        downloadRate = 0
        selectedVideoName = nil
        subtitleTracks = []
        playbackModeLabel = nil
        phase = .idle
    }

    private func runStreamSession(torrent: TorrentItem) async {
        do {
            let socket = try APIService.shared.openStreamSocket(hash: torrent.hash)
            streamSocket = socket
            try await APIService.shared.sendStreamSocketInit(
                socket: socket,
                magnet: torrent.magnet,
                hash: torrent.hash
            )

            while !Task.isCancelled {
                let event = try await APIService.shared.receiveStreamSocketEvent(socket: socket)
                try Task.checkCancellation()
                handleStreamEvent(event)
            }
        } catch is CancellationError {
            return
        } catch let apiError as APIError {
            if phase != .playing {
                if await fallbackToPreparedStream(torrent: torrent, reason: apiError.localizedDescription) {
                    return
                }
                phase = .failed(apiError.localizedDescription)
            }
        } catch {
            if phase != .playing {
                if await fallbackToPreparedStream(torrent: torrent, reason: error.localizedDescription) {
                    return
                }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func handleStreamEvent(_ event: StreamSocketEvent) {
        updateTransferStats(with: event)
        updateSelection(with: event)

        if let mode = event.playback_mode, !mode.isEmpty {
            currentPlaybackMode = mode
            playbackModeLabel = mode.uppercased()
        }

        if let message = event.message, !message.isEmpty {
            statusText = message
        }

        switch event.type {
        case "ready":
            let selection: APIService.PlaybackSelection?
            do {
                selection = try APIService.shared.playbackSelection(for: event)
            } catch {
                phase = .failed(error.localizedDescription)
                return
            }

            guard let selection else {
                phase = .failed("Stream is ready but no playable URL was returned")
                return
            }

            if selectedVideoName == nil {
                selectedVideoName = event.selected_media?.name ?? event.selected_video?.name
            }
            subtitleTracks = event.subtitle_tracks ?? subtitleTracks
            streamSocket?.cancel(with: .normalClosure, reason: nil)
            streamSocket = nil
            startPlayback(
                primaryURL: selection.primaryURL,
                fallbackURL: selection.fallbackURL,
                mode: selection.primaryMode,
                fallbackMode: selection.fallbackMode
            )

        case "error":
            let message = event.message ?? "Playback failed"
            if phase == .playing {
                statusText = message
            } else {
                phase = .failed(message)
            }

        default:
            break
        }
    }

    private func updateTransferStats(with event: StreamSocketEvent) {
        if let fileBytes = event.file_bytes, fileBytes > 0, let readyBytes = event.ready_bytes {
            let ratio = min(max(Double(readyBytes) / Double(fileBytes), 0), 1)
            progressPercent = Int((ratio * 100).rounded())
        } else if let progress = event.progress {
            progressPercent = Int((min(max(progress, 0), 1) * 100).rounded())
        }

        peerCount = event.num_peers ?? peerCount
        downloadRate = event.download_rate ?? downloadRate
    }

    private func updateSelection(with event: StreamSocketEvent) {
        if let selected = event.selected_media ?? event.selected_video {
            selectedVideoName = selected.name
        }
        if let tracks = event.subtitle_tracks {
            subtitleTracks = tracks
        }
    }

    private func startPlayback(primaryURL: URL, fallbackURL: URL?, mode: String?, fallbackMode: String?) {
        if isSwitchingPlayback {
            return
        }
        isSwitchingPlayback = true
        defer { isSwitchingPlayback = false }

        currentPlaybackURL = primaryURL
        pendingFallbackURL = fallbackURL
        pendingFallbackMode = fallbackMode
        currentPlaybackMode = mode ?? currentPlaybackMode
        playbackModeLabel = (mode ?? currentPlaybackMode)?.uppercased()

        playerItemObservation = nil
        removePlayerObservers()
        let asset = AVURLAsset(url: primaryURL)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5
        observePlayerItem(item)
        observePlayerItemNotifications(item)

        let activePlayer = player ?? AVPlayer()
        activePlayer.replaceCurrentItem(with: item)
        activePlayer.automaticallyWaitsToMinimizeStalling = true
        observePlayerTimeControl(activePlayer)
        player = activePlayer
        phase = .playing

        if let selectedVideoName {
            let modeText = playbackModeLabel.map { " via \($0)" } ?? ""
            statusText = "Streaming \(selectedVideoName)\(modeText)"
        }

        activePlayer.play()
        schedulePlaybackStartupCheck(for: primaryURL)
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        playerItemObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self else { return }
            Task { @MainActor in
                self.handlePlayerItemStatus(observedItem)
            }
        }
    }

    private func observePlayerTimeControl(_ player: AVPlayer) {
        if playerTimeControlObservation != nil {
            return
        }

        playerTimeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            guard let self else { return }
            Task { @MainActor in
                switch observedPlayer.timeControlStatus {
                case .playing:
                    self.statusText = "Playing \(self.selectedVideoName ?? "stream")"
                case .waitingToPlayAtSpecifiedRate:
                    if self.phase == .playing {
                        self.statusText = "Buffering \(self.selectedVideoName ?? "stream")…"
                    }
                case .paused:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func observePlayerItemNotifications(_ item: AVPlayerItem) {
        playerFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self.handlePlaybackFailure(error?.localizedDescription ?? "Playback failed")
        }

        playerStallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let reason = item.error?.localizedDescription ?? item.errorLog()?.events.last?.errorComment
            self.statusText = reason.map { "Playback stalled: \($0)" } ?? "Playback stalled. Waiting for more data…"
        }
    }

    private func removePlayerObservers() {
        if let playerFailureObserver {
            NotificationCenter.default.removeObserver(playerFailureObserver)
            self.playerFailureObserver = nil
        }
        if let playerStallObserver {
            NotificationCenter.default.removeObserver(playerStallObserver)
            self.playerStallObserver = nil
        }
    }

    private func handlePlayerItemStatus(_ item: AVPlayerItem) {
        guard item === player?.currentItem else {
            return
        }

        switch item.status {
        case .failed:
            let message = item.error?.localizedDescription
                ?? item.errorLog()?.events.last?.errorComment
                ?? "Playback failed"
            handlePlaybackFailure(message)

        case .readyToPlay:
            playbackStartupTask?.cancel()
            playbackStartupTask = nil
            if phase != .playing {
                phase = .playing
            }

        case .unknown:
            break

        @unknown default:
            break
        }
    }

    private func handlePlaybackFailure(_ message: String) {
        if let fallbackURL = pendingFallbackURL, fallbackURL != currentPlaybackURL {
            let failedMode = playbackModeLabel ?? "primary"
            let fallbackMode = pendingFallbackMode ?? inferredPlaybackMode(for: fallbackURL)
            pendingFallbackURL = nil
            pendingFallbackMode = nil
            statusText = "Primary \(failedMode.lowercased()) stream failed. Switching to \(fallbackMode.uppercased())…"
            Task { @MainActor in
                self.startPlayback(primaryURL: fallbackURL, fallbackURL: nil, mode: fallbackMode, fallbackMode: nil)
            }
            return
        }

        phase = .failed(message)
    }

    private func schedulePlaybackStartupCheck(for url: URL) {
        playbackStartupTask?.cancel()
        playbackStartupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self else { return }
            await self.checkPlaybackStartup(for: url)
        }
    }

    private func checkPlaybackStartup(for url: URL) async {
        guard currentPlaybackURL == url else { return }
        guard let player else { return }
        guard let item = player.currentItem else { return }
        if item.status == .readyToPlay && player.timeControlStatus == .playing {
            return
        }

        let currentSeconds = player.currentTime().seconds
        if currentSeconds.isFinite && currentSeconds > 0.5 {
            return
        }

        let message = item.error?.localizedDescription
            ?? item.errorLog()?.events.last?.errorComment
            ?? "Playback did not start"
        handlePlaybackFailure(message)
    }

    private func fallbackToPreparedStream(torrent: TorrentItem, reason: String) async -> Bool {
        statusText = "Live updates unavailable. Falling back to direct prepare…"

        do {
            guard let prepared = try await APIService.shared.prepareStream(
                magnet: torrent.magnet,
                hash: torrent.hash
            ) else {
                statusText = reason
                return false
            }

            selectedVideoName = prepared.payload.selected_media?.name ?? prepared.payload.selected_video?.name
            subtitleTracks = prepared.payload.subtitle_tracks ?? []

            startPlayback(
                primaryURL: prepared.url,
                fallbackURL: prepared.fallbackURL,
                mode: prepared.playbackMode,
                fallbackMode: prepared.fallbackMode
            )
            return true
        } catch {
            statusText = reason
            return false
        }
    }

    private func inferredPlaybackMode(for url: URL) -> String {
        url.pathExtension.lowercased() == "m3u8" ? "hls" : "direct"
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
                                    if let mode = vm.playbackModeLabel {
                                        Text("Mode: \(mode)")
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
            vm.start(torrent: torrent)
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
