import Foundation

enum APIConfig {
    static let defaultBaseURL = "https://torrentstream.asmsoftwares.tech"

    static var baseURL: String {
        normalized(UserDefaults.standard.string(forKey: "serverURL") ?? defaultBaseURL)
    }

    static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultBaseURL }

        var result = trimmed
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case noToken
    case httpError(Int, String)
    case decodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .noToken:
            return "Not authenticated"
        case .httpError(let code, let message):
            return "Server error \(code): \(message)"
        case .decodingError(let error):
            return "Decode error: \(error)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

final class APIService {
    static let shared = APIService()
    private init() {}

    var token: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func request(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        auth: Bool = true
    ) throws -> URLRequest {
        var req = URLRequest(url: try url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth {
            guard let tok = token else { throw APIError.noToken }
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(http.statusCode, message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performEmpty(_ req: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(http.statusCode, message)
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email: String; let password: String }
        let req = try request("/auth/login", method: "POST", body: Body(email: email, password: password), auth: false)
        return try await perform(req)
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email: String; let password: String }
        let req = try request("/auth/register", method: "POST", body: Body(email: email, password: password), auth: false)
        return try await perform(req)
    }

    func search(query: String, category: String = "all") async throws -> SearchResponse {
        let path = "/search/?query=\(query.urlEncoded)&category=\(category.urlEncoded)"
        let req = try request(path)
        return try await perform(req)
    }

    func trending(category: String = "all") async throws -> SearchResponse {
        let req = try request("/search/trending?category=\(category.urlEncoded)")
        return try await perform(req)
    }

    func recent() async throws -> SearchResponse {
        let req = try request("/search/recent")
        return try await perform(req)
    }

    func getWatchlist() async throws -> [ListItem] {
        let req = try request("/lists/watchlist")
        return try await perform(req)
    }

    func addWatchlist(_ torrent: TorrentItem) async throws {
        struct Resp: Decodable { let message: String }
        let req = try request("/lists/watchlist", method: "POST", body: torrent.toPayload())
        let _: Resp = try await perform(req)
    }

    func removeWatchlist(_ id: String) async throws {
        let req = try request("/lists/watchlist/\(id)", method: "DELETE")
        try await performEmpty(req)
    }

    func markWatched(_ id: String, watched: Bool) async throws {
        let req = try request("/lists/watchlist/\(id)/watched?watched=\(watched)", method: "PATCH")
        try await performEmpty(req)
    }

    func getWishlist() async throws -> [ListItem] {
        let req = try request("/lists/wishlist")
        return try await perform(req)
    }

    func addWishlist(_ torrent: TorrentItem) async throws {
        struct Resp: Decodable { let message: String }
        let req = try request("/lists/wishlist", method: "POST", body: torrent.toPayload())
        let _: Resp = try await perform(req)
    }

    func removeWishlist(_ id: String) async throws {
        let req = try request("/lists/wishlist/\(id)", method: "DELETE")
        try await performEmpty(req)
    }

    func getWatchLater() async throws -> [ListItem] {
        let req = try request("/lists/watchlater")
        return try await perform(req)
    }

    func addWatchLater(_ torrent: TorrentItem) async throws {
        struct Resp: Decodable { let message: String }
        let req = try request("/lists/watchlater", method: "POST", body: torrent.toPayload())
        let _: Resp = try await perform(req)
    }

    func removeWatchLater(_ id: String) async throws {
        let req = try request("/lists/watchlater/\(id)", method: "DELETE")
        try await performEmpty(req)
    }

    func getPlaylists() async throws -> [Playlist] {
        let req = try request("/lists/playlists")
        return try await perform(req)
    }

    func createPlaylist(name: String, description: String = "") async throws -> Playlist {
        struct Body: Encodable { let name: String; let description: String }
        let req = try request("/lists/playlists", method: "POST", body: Body(name: name, description: description))
        return try await perform(req)
    }

    func getPlaylist(_ id: String) async throws -> PlaylistDetail {
        let req = try request("/lists/playlists/\(id)")
        return try await perform(req)
    }

    func addToPlaylist(playlistId: String, torrent: TorrentItem, position: Int = 0) async throws {
        struct Body: Encodable {
            let torrent: TorrentPayload
            let position: Int
        }
        struct Resp: Decodable { let message: String }
        let req = try request(
            "/lists/playlists/\(playlistId)/items",
            method: "POST",
            body: Body(torrent: torrent.toPayload(), position: position)
        )
        let _: Resp = try await perform(req)
    }

    func removeFromPlaylist(playlistId: String, itemId: String) async throws {
        let req = try request("/lists/playlists/\(playlistId)/items/\(itemId)", method: "DELETE")
        try await performEmpty(req)
    }

    func deletePlaylist(_ id: String) async throws {
        let req = try request("/lists/playlists/\(id)", method: "DELETE")
        try await performEmpty(req)
    }

    // ─── Streaming (new streamlined flow) ───────────────────────────────

    func getStreamURL(magnet: String, hash: String) async throws -> URL? {
        // Start torrent backend session and return AVPlayer-compatible stream URL.
        let path = "/stream/magnet/\(hash.urlEncoded)?magnet=\(magnet.urlEncoded)"
        let req = try request(path)
        let response: MagnetStreamResponse = try await perform(req)

        guard let tok = token else { throw APIError.noToken }

        let absoluteURLString = (response.stream_url?.isEmpty == false)
            ? response.stream_url!
            : (APIConfig.baseURL + response.stream_path)

        guard var components = URLComponents(string: absoluteURLString) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: tok))
        components.queryItems = queryItems
        return components.url
    }

    @discardableResult
    func startMagnetSession(magnet: String, hash: String) async throws -> StreamStartResponse {
        var req = try request("/stream/start", method: "POST")
        let params = "magnet=\(magnet.urlEncoded)&torrent_hash=\(hash.urlEncoded)"
        req.url = URL(string: APIConfig.baseURL + "/stream/start?" + params)
        return try await perform(req)
    }

    func streamStatus(hash: String) async throws -> StreamStatus {
        let req = try request("/stream/status/\(hash.urlEncoded)")
        return try await perform(req)
    }

    func torrentFiles(hash: String) async throws -> [TorrentFile] {
        let req = try request("/stream/files/\(hash.urlEncoded)")
        let response: TorrentFilesResponse = try await perform(req)
        return response.files
    }

    func streamFileURL(hash: String, fileIndex: Int) -> URL? {
        guard let tok = token else { return nil }
        let value = "\(APIConfig.baseURL)/stream/file/\(hash.urlEncoded)/\(fileIndex)?token=\(tok.urlEncoded)"
        return URL(string: value)
    }

    func bestPlayableVideo(from files: [TorrentFile]) -> TorrentFile? {
        files
            .filter(\.isPlayableVideo)
            .sorted { lhs, rhs in
                if lhs.size == rhs.size {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.size > rhs.size
            }
            .first
    }
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
