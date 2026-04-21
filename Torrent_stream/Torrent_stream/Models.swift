import Foundation

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let user_id: String
    let email: String

    private enum CodingKeys: String, CodingKey {
        case access_token
        case token_type
        case user_id
        case email
    }

    init(access_token: String, token_type: String, user_id: String, email: String) {
        self.access_token = access_token
        self.token_type = token_type
        self.user_id = user_id
        self.email = email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try container.decode(String.self, forKey: .access_token)
        token_type = try container.decode(String.self, forKey: .token_type)
        user_id = try container.decodeStringValue(forKey: .user_id)
        email = try container.decode(String.self, forKey: .email)
    }
}

struct TorrentItem: Codable, Identifiable, Hashable {
    var id: String { hash.isEmpty ? name : hash }
    let name: String
    let size: String
    let seeders: String
    let leechers: String
    let magnet: String
    let hash: String
    let poster: String
    let category: String
    let site: String
    let url: String
    let date: String?
    let uploader: String?
    let screenshot: [String]?
    let files: [String]?

    static func == (lhs: TorrentItem, rhs: TorrentItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SearchResponse: Codable {
    let data: [TorrentItem]
    let current_page: Int?
    let total_pages: Int?
    let total: Int?
    let time: Double?
}

struct ListItem: Codable, Identifiable {
    let list_id: String
    var id: String { list_id }
    let added_at: String
    let torrent: TorrentItemDB
    let watched: Bool?

    private enum CodingKeys: String, CodingKey {
        case list_id
        case added_at
        case torrent
        case watched
    }

    init(list_id: String, added_at: String, torrent: TorrentItemDB, watched: Bool?) {
        self.list_id = list_id
        self.added_at = added_at
        self.torrent = torrent
        self.watched = watched
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list_id = try container.decodeStringValue(forKey: .list_id)
        added_at = try container.decode(String.self, forKey: .added_at)
        torrent = try container.decode(TorrentItemDB.self, forKey: .torrent)
        watched = try container.decodeIfPresent(Bool.self, forKey: .watched)
    }
}

struct TorrentItemDB: Codable, Identifiable {
    let id: String
    let name: String
    let size: String
    let seeders: String
    let leechers: String
    let magnet: String
    let hash: String
    let poster: String
    let category: String
    let site: String
    let url: String
    let added_at: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case seeders
        case leechers
        case magnet
        case hash
        case poster
        case category
        case site
        case url
        case added_at
    }

    init(
        id: String,
        name: String,
        size: String,
        seeders: String,
        leechers: String,
        magnet: String,
        hash: String,
        poster: String,
        category: String,
        site: String,
        url: String,
        added_at: String
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.seeders = seeders
        self.leechers = leechers
        self.magnet = magnet
        self.hash = hash
        self.poster = poster
        self.category = category
        self.site = site
        self.url = url
        self.added_at = added_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringValue(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(String.self, forKey: .size)
        seeders = try container.decode(String.self, forKey: .seeders)
        leechers = try container.decode(String.self, forKey: .leechers)
        magnet = try container.decode(String.self, forKey: .magnet)
        hash = try container.decode(String.self, forKey: .hash)
        poster = try container.decode(String.self, forKey: .poster)
        category = try container.decode(String.self, forKey: .category)
        site = try container.decode(String.self, forKey: .site)
        url = try container.decode(String.self, forKey: .url)
        added_at = try container.decode(String.self, forKey: .added_at)
    }

    func toTorrentItem() -> TorrentItem {
        TorrentItem(
            name: name,
            size: size,
            seeders: seeders,
            leechers: leechers,
            magnet: magnet,
            hash: hash,
            poster: poster,
            category: category,
            site: site,
            url: url,
            date: nil,
            uploader: nil,
            screenshot: nil,
            files: nil
        )
    }
}

struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let created_at: String
    let item_count: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case created_at
        case item_count
    }

    init(id: String, name: String, description: String, created_at: String, item_count: Int?) {
        self.id = id
        self.name = name
        self.description = description
        self.created_at = created_at
        self.item_count = item_count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringValue(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        created_at = try container.decode(String.self, forKey: .created_at)
        item_count = try container.decodeIfPresent(Int.self, forKey: .item_count)
    }
}

struct PlaylistDetail: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let created_at: String
    let items: [PlaylistItemEntry]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case created_at
        case items
    }

    init(id: String, name: String, description: String, created_at: String, items: [PlaylistItemEntry]) {
        self.id = id
        self.name = name
        self.description = description
        self.created_at = created_at
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringValue(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        created_at = try container.decode(String.self, forKey: .created_at)
        items = try container.decode([PlaylistItemEntry].self, forKey: .items)
    }
}

struct PlaylistItemEntry: Codable, Identifiable {
    let item_id: String
    var id: String { item_id }
    let position: Int
    let torrent: TorrentItemDB

    private enum CodingKeys: String, CodingKey {
        case item_id
        case position
        case torrent
    }

    init(item_id: String, position: Int, torrent: TorrentItemDB) {
        self.item_id = item_id
        self.position = position
        self.torrent = torrent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item_id = try container.decodeStringValue(forKey: .item_id)
        position = try container.decode(Int.self, forKey: .position)
        torrent = try container.decode(TorrentItemDB.self, forKey: .torrent)
    }
}

struct TorrentPayload: Codable {
    let name: String
    let size: String
    let seeders: String
    let leechers: String
    let magnet: String
    let hash: String
    let poster: String
    let category: String
    let site: String
    let url: String
}

extension TorrentItem {
    func toPayload() -> TorrentPayload {
        TorrentPayload(
            name: name,
            size: size,
            seeders: seeders,
            leechers: leechers,
            magnet: magnet,
            hash: hash,
            poster: poster,
            category: category,
            site: site,
            url: url
        )
    }
}

struct StreamStartResponse: Codable {
    let status: String
    let hash: String
    let magnet: String?

    init(status: String, hash: String, magnet: String? = nil) {
        self.status = status
        self.hash = hash
        self.magnet = magnet
    }
}

struct StreamStatus: Codable {
    let hash: String
    let progress: Double
    let download_rate: Int
    let upload_rate: Int
    let num_peers: Int
    let state: String
    let has_metadata: Bool
    let paused: Bool
}

struct TorrentFilesResponse: Codable {
    let hash: String
    let files: [TorrentFile]
}

struct MagnetStreamResponse: Codable {
    let status: String?
    let prepared: Bool?
    let hash: String
    let stream_path: String
    let stream_url: String?
    let magnet: String?
    let selected_video: StreamSelectedVideo?
    let subtitles_available: Bool?
    let subtitle_tracks: [StreamSubtitleTrack]?
    let message: String
}

struct StreamSelectedVideo: Codable {
    let name: String
    let path: String
    let size: Int64
}

struct StreamSubtitleTrack: Codable, Identifiable {
    let index: Int
    let name: String
    let path: String
    let size: Int64
    let ext: String
    let downloaded: Bool

    var id: Int { index }
}

struct TorrentFile: Codable, Identifiable, Hashable {
    let index: Int
    let name: String
    let path: String?
    let size: Int64

    var id: Int { index }

    var displayName: String {
        let base = (path?.isEmpty == false ? path! : name)
        return URL(fileURLWithPath: base).lastPathComponent
    }

    var fileExtension: String {
        URL(fileURLWithPath: displayName).pathExtension.lowercased()
    }

    var isPlayableVideo: Bool {
        Self.videoExtensions.contains(fileExtension)
    }

    static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "webm", "avi", "mpg", "mpeg", "ts", "m2ts", "wmv"
    ]
}

private extension KeyedDecodingContainer {
    func decodeStringValue(forKey key: Key) throws -> String {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Int64.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected a string-compatible value"
            )
        )
    }
}
