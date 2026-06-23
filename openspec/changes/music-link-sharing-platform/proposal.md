## Why

Musicians, producers, sound engineers, and other audio professionals routinely need to share works-in-progress, mixes, and masters with collaborators and clients. Today that means attaching large files, juggling cloud drive permissions, or sending files that recipients can't preview without downloading first. throw.it solves this by letting anyone upload an audio file and share a single link that opens a playable page in the browser—no account required for the listener, the same way a YouTube link works.

## What Changes

- Introduce a web platform with two upload modes:
  - **Signed-in uploaders** persist tracks in a library with permanent shareable URLs
  - **Anonymous uploaders** get temporary hosting (10-minute TTL) with clear expiry messaging—no account, no management, fire-and-forget
- Serve a public playback page at each URL so anyone with the link can stream the track in-browser
- Support common professional audio formats (MP3, WAV, FLAC, AAC, OGG) with format warnings and graceful playback errors (no transcoding in MVP)
- Give signed-in uploaders a library to view, copy links for, rename, delete, and see listen counts for their tracks (5 GB total storage cap per account)
- Provide magic link authentication for uploaders who want persistent storage (24-hour sessions, multi-device)
- Add track metadata display on the playback page (title, duration) and a public listen count
- Track listen counts per audio file (fresh play from start; no count on pause/resume or scrub-to-start mid-pass; count again after track ends naturally)
- Show listen counts to uploaders in the library and publicly on playback pages (signed-in and anonymous tracks)
- Enforce anonymous abuse limits (3 active tracks per IP, 100 MB combined per IP, one upload at a time)

## Capabilities

### New Capabilities

- `audio-upload`: Accept, validate, and store audio file uploads from signed-in uploaders (500 MB per file, 5 GB account cap)
- `anonymous-upload`: Accept temporary audio uploads from unauthenticated users with IP-based quotas and 10-minute TTL
- `shareable-playback`: Generate unique public URLs and serve a browser-based audio player page with refresh-on-demand streaming
- `track-management`: Allow signed-in uploaders to list, rename, copy share links for, and delete their uploads
- `uploader-auth`: Optional magic link authentication for uploaders who want persistent storage; listeners never need accounts

### Modified Capabilities

- _(none — greenfield project)_

## Impact

- New full-stack application (frontend, internal API routes, storage layer, database)
- S3-compatible object storage for audio files (Cloudflare R2 for MVP—free tier, zero egress)
- PostgreSQL for track metadata, share tokens, uploader records, and IP quota tracking
- Background cleanup jobs for expired anonymous tracks, orphaned uploads, and retired slugs
- Web UI only—no public API; all routes are internal to the application
- Target $0/month on free tiers (Vercel Hobby, Neon Postgres, R2, Resend) at early launch scale
- No existing code affected — this is the initial product build for throw.it
