# TorrentStream

TorrentStream is a SwiftUI iOS mobile streaming and media discovery app backed by a FastAPI service. The app lets users sign in, search torrent metadata, inspect details, stream playable media, manage personal lists, and share selected items with the community.

## Features

- Account registration and login with JWT-based authentication.
- Onboarding flow with theme-aware introduction screens.
- Configurable backend server URL.
- Torrent search with trending and recent history views.
- Torrent detail page with metadata, screenshots, and actions.
- In-app playback with streaming preparation and fallback support.
- Watchlist and Watch Later management.
- Custom playlists with add, remove, and play-all flows.
- Community feed with posts, tags, votes, and comments.
- Profile screen with theme toggle and sign-out.

## Project Structure

- `Torrent_stream/` - SwiftUI iOS application source code.
- `Report/images/` - Simulator screenshots and architecture diagrams used in the report.
- `backend-torrent-stream/` - FastAPI backend service.

## Screenshots

The following screenshots are included in the project report assets and can be reused in presentations or documentation.

## Feature to Screenshot Map

| Feature | Screenshot description |
|---|---|
| Onboarding | Search Torrents, Stream Instantly, Build Your Lists, Join the Community. |
| Authentication | Login screen, register screen. |
| Server configuration | Backend URL settings screen. |
| Search and discovery | Trending, recent, and search results screens. |
| Detail and playback | Torrent detail, stream preparation, and active playback screens. |
| Playlists | Add to playlist sheet, playlists overview, and playlist detail screen. |
| Community | Create post screen, feed screen, and post detail with comments. |
| Watchlist and Watch Later | Saved items and queue screens. |
| Profile and theme | Profile screen with theme and settings controls. |

| Screenshot | Description |
|---|---|
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.13.23.png) | Onboarding: Search Torrents. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.13.29.png) | Onboarding: Stream Instantly. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.13.35.png) | Onboarding: Build Your Lists. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.13.42.png) | Onboarding: Join the Community. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.14.22.png) | Login screen with email and password fields. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.14.33.png) | Register screen for creating a new account. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.14.55.png) | Server configuration screen for backend URL settings. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.15.17.png) | Search tab showing trending content. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.15.26.png) | Search tab showing recent items. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.16.19.png) | Search results after entering a query. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.17.04.png) | Torrent detail screen with metadata and actions. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.17.16.png) | Stream preparation screen with progress feedback. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.19.13.png) | Active playback screen in the video player. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.20.14.png) | Add to playlist sheet. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.20.31.png) | Create a community post screen. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.20.45.png) | Community feed with posts and votes. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.20.51.png) | Community post detail with comments. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.20.57.png) | Watchlist screen. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.21.02.png) | Watch Later screen. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.21.06.png) | Playlists overview screen. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.21.10.png) | Playlist detail screen. |
| ![](../Report/images/Simulator%20Screenshot%20-%20iPhone%2014%20Pro%20-%202026-04-21%20at%2014.21.15.png) | Profile screen with theme and settings controls. |

## Diagrams

The report also includes supporting architecture and data model diagrams:

- [High-level architecture](../Report/images/High_level_Architecture.png)
- [Entity-relationship diagram](../Report/images/ERD.png)
- [Use case diagram](../Report/images/USecase.png)

## Notes

- The iOS client is located in `Torrent_stream/Torrent_stream/`.
- The backend service is located in `backend-torrent-stream/`.
- Screenshot assets are stored in the report folder rather than inside the Xcode project, so the README links them from `Report/images/`.