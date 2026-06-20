## Context

throw.it is a greenfield project. There is no existing codebase, infrastructure, or user base. The product targets audio professionals who need a frictionless way to share playable audio links, modeled after how YouTube links work for video.

The platform operates in **two upload modes**:

1. **Signed-in** — magic link auth, persistent library, permanent share URLs, 5 GB account cap
2. **Anonymous** — no account, 10-minute TTL, fire-and-forget, IP-based quotas

Constraints:

- Listeners must never need an account
- Uploaders can choose anonymous temp hosting or sign in for persistent storage
- Audio files can be large (up to 500 MB signed-in, 100 MB anonymous quota); storage and streaming must handle this reliably
- Share URLs use short random slugs at `/t/{slug}`; slugs are never reused after delete or expiry
- MVP targets $0/month on free tiers at early public launch scale (hundreds of uploaders)

## Goals / Non-Goals

**Goals:**

- Upload audio → get a shareable link → anyone can play in-browser
- Dual-mode upload: persistent (signed-in) or temporary (anonymous, 10 min)
- Magic link auth for uploaders who want a library (24-hour sessions)
- Simple library for managing signed-in uploads (rename, delete, copy link)
- Fast playback page load with refresh-on-demand streaming
- Rich link previews when URLs are shared in chat apps (Open Graph)
- Graceful handling of unsupported browser formats (warnings at upload, errors at playback)

**Non-Goals (MVP):**

- Waveform visualization
- Comments, likes, or social features
- Playlists or albums
- Audio transcoding or format conversion
- Download button for listeners (streaming only in MVP)
- Custom domains or branded pages
- Team/organization accounts
- Mobile native apps
- Content moderation or copyright detection
- Analytics dashboard for uploaders
- Public API for third-party integrations
- CDN (deferred until global latency or cost warrants it)

## Decisions

### 1. Monorepo with Next.js full-stack app

**Choice:** Next.js 15 (App Router) as a single deployable unit handling both frontend and internal API routes.

**Rationale:** Greenfield project with a small surface area. Next.js gives SSR for playback pages (critical for Open Graph previews), API routes for upload/auth, and a React frontend in one repo. Fits the "link in, player out" product shape. No public API—all routes serve the web UI only.

**Alternatives considered:**

- Separate React SPA + Express API — more boilerplate for a solo/small team MVP
- Rails/Django — strong but heavier setup for a link-sharing product

### 2. Object storage for audio files

**Choice:** S3-compatible object storage via **Cloudflare R2** (AWS S3 API compatible; MinIO or LocalStack for local dev).

**Rationale:** Audio files are large binary blobs; they don't belong in a database or on the app server's filesystem. R2 gives durable storage, direct streaming via presigned URLs, zero egress fees (critical for streaming cost at MVP), and a 10 GB free tier. S3 API compatibility keeps the SDK and presigned URL patterns unchanged.

**Alternatives considered:**

- AWS S3 — viable but egress fees add up with audio streaming
- Store on app server disk — doesn't scale, lost on redeploy

### 3. PostgreSQL for metadata

**Choice:** PostgreSQL via a lightweight ORM (Drizzle), hosted on **Neon free tier** for MVP.

**Rationale:** Track metadata, uploader records, magic link tokens, IP quota tracking, and upload sessions are relational and small. Postgres is reliable and well-supported. Drizzle keeps the schema explicit and type-safe without heavy ORM magic.

### 4. URL slug strategy

**Choice:** Short random slug (8 alphanumeric characters) at path `/t/{slug}`. **Slugs are never reused** after track deletion or anonymous expiry.

**Rationale:** Short URLs are easy to share. 8 chars from a 62-char alphabet gives ~218 trillion combinations — collision-safe at any realistic scale. Retiring slugs permanently ensures old links never point at different audio. Example: `throw.it/t/xK9mP2qR`.

**Alternatives considered:**

- UUID in URL — ugly and long for sharing
- Title-based slugs — collision-prone and change when title changes
- Slug reuse — rejected; risks old Slack links pointing at wrong audio

### 5. Magic link authentication

**Choice:** Email magic links with 15-minute expiry (reusable within window until first successful sign-in), **24-hour session cookies**, multi-device sessions allowed.

**Rationale:** Matches the "no friction" product goal. Uploaders are professionals who check email; passwords add support burden and drop-off. Resend handles email delivery on free tier. Magic links are reusable within 15 minutes (phone + laptop). Already-signed-in users are gently redirected to library.

**Alternatives considered:**

- OAuth (Google/GitHub) — adds dependency and excludes users without those accounts
- 30-day sessions — rejected; 24 hours chosen for security
- One-time magic links — rejected; reusable within 15 min is friendlier for multi-device

### 6. Refresh-on-demand streaming via presigned URLs

**Choice:** Playback page loads metadata via SSR; audio element streams from presigned R2 URLs that **refresh on demand** (new URL fetched on play and when current URL expires). TTL per presigned URL: 1–4 hours for signed-in tracks; for anonymous tracks, URLs valid only until track `expires_at`.

**Rationale:** Browser `<audio>` element handles range requests natively when the source supports HTTP 206. Presigned URLs keep the bucket private. Refresh-on-demand prevents mid-playback failures on long tracks or paused tabs without exposing a permanent raw file URL.

**Alternatives considered:**

- Proxy all audio through API — expensive on bandwidth and compute
- Public bucket — no access control if slug is guessed
- Fixed short TTL without refresh — causes mid-playback failures

### 7. Upload flow with upload sessions

**Choice:** Server issues presigned PUT URL + short-lived `upload_id`; client uploads directly to R2; confirm step promotes session to track record. **Same-ticket retry** on confirm failure. Anonymous uploads blocked for 15 minutes while a session is in-progress.

**Rationale:** Avoids routing 500 MB files through the Next.js server. Quota counts only confirmed tracks (orphans don't consume anonymous IP limits). Sweeper job deletes R2 objects with no matching track record.

**Alternatives considered:**

- Upload through app server — doesn't scale for large files
- No pending state — orphan storage leaks

### 8. Dual-mode upload

**Choice:** Anonymous temp upload (10 min TTL, fire-and-forget) and signed-in persistent upload coexist. No claim flow—anonymous users must re-upload to persist.

**Rationale:** Lowers friction for quick handoffs ("paste link in Slack now"). Signed-in mode is the upgrade path for producers who need a library. Clear UX separation prevents confusion about persistence.

**Anonymous limits:**

- 3 active tracks per IP (resets when TTL files expire and are deleted)
- 100 MB combined storage per IP across active anonymous tracks
- 1 upload at a time (no concurrent; in-progress session blocks for up to 15 min)
- Shared-network IP blocking acceptable for MVP

### 9. Signed-in storage quota

**Choice:** 5 GB total per uploader account, 500 MB max per file, no track-count cap.

**Rationale:** Enough for real producer workflows (~15–40 tracks at typical sizes). Predictable cost at B-scale public launch. Clear "library full" error when exceeded.

### 10. Duration extraction

**Choice:** Browser reports duration during upload confirm; player `<audio>` metadata as fallback if missing.

**Rationale:** Avoids server-side probing of 500 MB files on Vercel serverless (timeout risk). Fast share link issuance matters for 10-minute anonymous window.

### 11. Format compatibility (no transcoding)

**Choice:** Accept all listed formats; warn at upload for browser-risky formats (e.g. OGG on Safari); show graceful playback error if browser can't decode.

**Rationale:** Transcoding requires a background worker and doubles storage—breaks $0 MVP budget. Warnings set expectations; errors are honest.

### 12. Deployment target

**Choice:** Vercel Hobby (free) for Next.js; Neon Postgres (free); Cloudflare R2 (free tier); Resend (free tier).

**Rationale:** $0/month target for early public launch. No CDN for MVP. Single region is fine until global latency becomes a problem.

## Risks / Trade-offs

- **[Large file upload failures]** → Same-ticket retry on confirm; sweeper for orphaned R2 objects; MVP shows clear error and retry button
- **[Magic link deliverability]** → Use Resend; monitor bounce rates
- **[Storage costs at scale]** → 5 GB/uploader cap; 10-min anonymous TTL; R2 zero egress; monitor usage
- **[No transcoding]** → Some browsers won't play OGG/FLAC natively; upload warnings and playback errors; consider transcoding pipeline post-MVP
- **[Slug guessing]** → 8-char random slugs are unguessable in practice; no public directory of tracks
- **[No download protection]** → Anyone with the link can stream; presigned URLs expire but page re-fetches; true DRM is a non-goal
- **[Shared IP rate limits]** → Offices/coffee shops share one IP; acceptable for MVP; slots reset when anonymous TTL expires
- **[Neon cold starts]** → Free tier DB sleeps when idle; first request after idle may be slow
- **[R2 free tier storage]** → 10 GB limit; upgrade to paid storage as usage grows (~$0.015/GB)

## Migration Plan

Greenfield — no migration needed. Deployment sequence:

1. Provision Neon Postgres, R2 bucket, Resend domain
2. Run database migrations
3. Deploy Next.js app to Vercel with environment variables
4. Configure cleanup cron (expired anonymous tracks, orphaned uploads)
5. Smoke test: anonymous upload → share → play; sign in → upload → library → rename → delete

Rollback: revert Vercel deployment; database and R2 objects are independent and safe to leave in place.

## Open Questions

- Custom track artwork/cover image on upload — nice for link previews but adds scope
- Transcoding pipeline — post-MVP when "won't play on iPhone" becomes common
- CDN — add when global latency or storage egress costs warrant it
- Paid tiers with higher storage quotas — post-MVP monetization
