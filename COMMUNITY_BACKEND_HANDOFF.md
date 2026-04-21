# Community Backend Handoff

This document describes the backend API contract the iOS frontend now expects for the Community feature.

## Goal

Add an authenticated Community API where:

- a logged-in user can create a post from a torrent plus an optional caption
- other logged-in users can view the feed
- users can comment on posts
- users can upvote or downvote posts
- feed order is based on score, then recency

The existing frontend has already been wired to call these endpoints from the iOS app.

## Auth

All Community endpoints must require the same Bearer token auth already used by:

- `/search/*`
- `/lists/*`
- `/auth/me`

Frontend sends:

```http
Authorization: Bearer <jwt>
Content-Type: application/json
```

## Route Group

Add a new router group:

```text
/community/*
```

## Required Endpoints

### 1. Get community feed

```http
GET /community/posts
```

Return all posts sorted by:

1. `score` descending
2. `created_at` descending

Response:

```json
[
  {
    "id": "post_001",
    "author_email": "alice@example.com",
    "caption": "Loved the atmosphere in this one.",
    "torrent": {
      "name": "Movie Name 1080p",
      "size": "2147483648",
      "seeders": "120",
      "leechers": "8",
      "magnet": "magnet:?xt=urn:btih:...",
      "hash": "ABC123HASH",
      "poster": "",
      "category": "movies",
      "site": "apibay",
      "url": ""
    },
    "score": 7,
    "upvote_count": 10,
    "downvote_count": 3,
    "comment_count": 4,
    "user_vote": 1,
    "created_at": "2026-04-19T18:30:00Z"
  }
]
```

Notes:

- `user_vote` must be:
  - `1` if current user upvoted
  - `-1` if current user downvoted
  - `0` if current user has not voted
- `created_at` must be returned as a JSON string
- ids must be string-compatible

### 2. Create a post

```http
POST /community/posts
```

Request:

```json
{
  "caption": "Loved the atmosphere in this one.",
  "torrent": {
    "name": "Movie Name 1080p",
    "size": "2147483648",
    "seeders": "120",
    "leechers": "8",
    "magnet": "magnet:?xt=urn:btih:...",
    "hash": "ABC123HASH",
    "poster": "",
    "category": "movies",
    "site": "apibay",
    "url": ""
  }
}
```

Response: return the created post in the same shape as `GET /community/posts/{post_id}`.

Important:

- `caption` is optional and may be empty
- `torrent.name` should be required
- backend should store the torrent snapshot embedded in the post

### 3. Get single post

```http
GET /community/posts/{post_id}
```

Response:

```json
{
  "id": "post_001",
  "author_email": "alice@example.com",
  "caption": "Loved the atmosphere in this one.",
  "torrent": {
    "name": "Movie Name 1080p",
    "size": "2147483648",
    "seeders": "120",
    "leechers": "8",
    "magnet": "magnet:?xt=urn:btih:...",
    "hash": "ABC123HASH",
    "poster": "",
    "category": "movies",
    "site": "apibay",
    "url": ""
  },
  "score": 7,
  "upvote_count": 10,
  "downvote_count": 3,
  "comment_count": 4,
  "user_vote": -1,
  "created_at": "2026-04-19T18:30:00Z"
}
```

### 4. Get comments for a post

```http
GET /community/posts/{post_id}/comments
```

Return comments ordered by:

1. `created_at` ascending

Response:

```json
[
  {
    "id": "comment_001",
    "author_email": "bob@example.com",
    "content": "Totally agree.",
    "created_at": "2026-04-19T19:00:00Z"
  }
]
```

### 5. Add comment

```http
POST /community/posts/{post_id}/comments
```

Request:

```json
{
  "content": "Totally agree."
}
```

Response:

```json
{
  "id": "comment_001",
  "author_email": "bob@example.com",
  "content": "Totally agree.",
  "created_at": "2026-04-19T19:00:00Z"
}
```

Important:

- reject empty or whitespace-only comments
- increment the post `comment_count`

### 6. Vote on a post

```http
PUT /community/posts/{post_id}/vote
```

Request:

```json
{
  "value": 1
}
```

Allowed values:

- `1` = upvote
- `-1` = downvote
- `0` = clear existing vote

Response:

```json
{
  "score": 7,
  "upvote_count": 10,
  "downvote_count": 3,
  "comment_count": 4,
  "user_vote": 1
}
```

Vote behavior:

- one vote per user per post
- switching from `1` to `-1` must update counts correctly
- switching from `-1` to `1` must update counts correctly
- sending the same vote again may return unchanged state, but frontend also supports explicit clear with `0`

## Suggested Backend Models

Use three new persistence models/documents:

### CommunityPost

Fields:

- `user_id`
- `author_email`
- `caption`
- `torrent`
- `score`
- `upvote_count`
- `downvote_count`
- `comment_count`
- `created_at`

### CommunityComment

Fields:

- `post_id`
- `user_id`
- `author_email`
- `content`
- `created_at`

### CommunityPostVote

Fields:

- `post_id`
- `user_id`
- `value` (`1` or `-1`)
- `created_at`
- `updated_at`

Recommended index:

- unique composite index on `(post_id, user_id)`

## App Assumptions

The frontend already assumes the following:

- all keys are `snake_case`
- `author_email` is returned directly by backend
- app derives author display name from the email handle locally
  - example: `alice@example.com` -> `alice`
- comments are only loaded on post detail, not inside feed rows
- feed uses backend ordering and does not re-sort locally
- no pagination in v1
- no edit/delete/report/moderation in v1
- votes apply only to posts, not comments

## UI Entry Points Already Wired

The frontend now does this:

- Search screen nav bar opens Community feed
- Torrent detail screen has a `Post` button
- that button opens a composer and sends `POST /community/posts`
- community detail screen loads:
  - `GET /community/posts/{post_id}`
  - `GET /community/posts/{post_id}/comments`
- vote buttons call:
  - `PUT /community/posts/{post_id}/vote`
- comment submission calls:
  - `POST /community/posts/{post_id}/comments`

## Error Handling Expectations

Please return normal non-2xx errors with a readable JSON/string body, because the current Swift `APIService` surfaces backend error text directly in the UI.

Recommended examples:

- `400` for invalid payload
- `401` for missing/invalid token
- `404` for unknown post id

## Important Compatibility Note

Please do not rename keys or switch to camelCase.

The frontend decoders now expect exactly:

- `author_email`
- `upvote_count`
- `downvote_count`
- `comment_count`
- `user_vote`
- `created_at`

If you keep that contract, the frontend should connect cleanly.
