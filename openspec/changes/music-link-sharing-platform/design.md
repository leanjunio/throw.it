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
- Per-track listen counts (public on playback page, visible in uploader library) without a full analytics dashboard
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
- Analytics dashboard for uploaders (listen count per track is in scope; time-series, geography, and per-listener breakdown are not)
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

### 13. Listen counting

**Choice:** Single integer `listen_count` per track, incremented server-side via an unauthenticated `POST` from the playback player. Count on fresh play from the beginning only; do not count pause/resume or scrub-to-start mid-pass; count again after the track ends naturally and the listener starts a new pass. Treat `currentTime < 0.5` s as "at the beginning." Client tracks `listenCountedForPass` (reset on `ended` event). Display publicly on playback page and in signed-in library. Anonymous tracks use the same rules during their TTL. No rate limiting or per-listener deduplication in MVP.

**Rationale:** Uploaders want lightweight feedback that a link was opened ("did my client listen?") without building an analytics product. Session-per-pass counting avoids inflating counts on pause/resume while still counting genuine replays after a full listen. Server-side persistence keeps counts visible across visitors; client-only counting would be meaningless for shared links.

**Alternatives considered:**

- Count every play button click — inflates on pause/resume
- Position-only rule (count whenever `currentTime ≈ 0` at play) — counts scrub-back-to-start as new listens
- Full analytics (unique listeners, geography, time series) — out of MVP scope
- IP rate limiting per track — deferred; acceptable inflation risk at early scale

## Frontend & UI

### UI design references

**Source of truth for layout, copy, and visual styling during frontend implementation.** Open the prototypes in a browser from the project index.

**Design root:** `/Users/leanjunio/Documents/projects/open-design/.od/projects/c5e34f64-b0b3-40ad-a5ab-b55822522dbf`

| App route | Prototype file | States / variants (state switcher in prototype) |
|-----------|----------------|---------------------------------------------------|
| — (hub) | `index.html` | Links to all route prototypes |
| `/` | `landing.html` | Single view (signed-out nav) |
| `/upload` | `upload.html` | `interactive` (idle → uploading → success), `quota` (5 GB account cap error) |
| `/upload/temp` | `upload-temp.html` | `interactive` (idle → uploading → success), `ip-tracks`, `ip-storage` |
| `/sign-in` | `sign-in.html` | `email`, `check-email`, `expired` |
| `/library` | `library.html` | `populated` (rename + delete dialogs), `empty` |
| `/t/[slug]` | `playback.html` | `playing`, `anonymous`, `pluralization`, `loading`, `error`, `404`, `countable` |

**Shared assets:**

- `css/shared.css` — design tokens (colors, type scale, spacing), component patterns (nav, buttons, dropzone, player, dialogs, table). Map to Tailwind + shadcn during implementation.
- `js/shared.js` — interaction reference only (theme dropdown, upload state machine, dialogs, copy-to-clipboard, player scrubber). Reimplement in React; do not ship this script.

**How to use during implementation:**

1. Open `index.html` in a browser; walk each route before building the matching Next.js page.
2. Match structure, spacing, copy, and component hierarchy from the prototype; translate CSS variables to Tailwind `dark:` tokens.
3. Use the state switcher at the bottom of multi-state prototypes to implement every variant listed above.
4. When this design doc and a prototype disagree, **this design doc wins** for behavior and data rules; **the prototype wins** for layout and visual polish unless noted below.

### Visual direction

**Choice:** Vercel-inspired — clean, minimal, professional. Light and dark palettes with subtle gray borders, generous whitespace, typography-forward hierarchy. Product name stays casual in copy; UI stays calm.

**Stack:** Tailwind CSS, shadcn/ui, Geist Sans (UI) + Geist Mono (URLs/slugs), Sonner toasts for transient feedback, inline errors on forms.

**Brand (MVP):** Text wordmark "throw.it" in nav — no custom logo.

**Motion:** Minimal — hover/focus transitions only.

**Language:** English only; hardcoded strings (no i18n library).

### Theme

**Choice:** Light, Dark, and System via `next-themes`. Default on first visit: **System** (follows `prefers-color-scheme`). Preference stored in localStorage. Theme toggle in nav (dropdown: Light / Dark / System). All pages including playback support both themes via Tailwind `dark:` variants.

### Site routes (pages)

| Route | Purpose | Auth |
|-------|---------|------|
| `/` | Landing — explains both upload modes, CTAs to each path | Public |
| `/upload` | Persistent upload | Required |
| `/upload/temp` | Anonymous 10-min upload | Public; redirects to `/upload` if signed in |
| `/sign-in` | Magic link email entry | Public |
| `/auth/verify` | Magic link callback → redirects to `/library` | — |
| `/library` | Track library | Required |
| `/t/[slug]` | Public playback | Public |

Post-sign-in redirect is always `/library` (no return-URL / `?next=` logic).

### App shell

**Choice:** Top nav on every page (including playback). No footer for MVP.

Nav contents: wordmark (links to `/`), Library (signed-in only), theme toggle, Sign in / Sign out.

Single root `app/layout.tsx` wraps all pages — no route groups for MVP.

### Upload UX

**File selection:** Drag-and-drop zone + "Choose file" button on both upload pages.

**Flow:** Single screen, manual start — pick file → optional title (signed-in only) → click Upload → progress bar → success panel.

**Signed-in (`/upload`):** Optional title field; defaults to filename without extension.

**Anonymous (`/upload/temp`):** No title field; title derived from uploaded filename (without extension).

**Post-upload:** Stay on upload page. Success panel shows share link, copy button, Preview link (opens `/t/[slug]` in same tab), and Upload another to reset the form.

**Upload progress:** Custom hook using XMLHttpRequest against presigned R2 PUT URL.

### Library UX

**Layout:** Simple table — Title, Duration, Date, Listens, Actions.

**Share links:** Copy button only (URL hidden); Sonner toast confirms copy.

**Rename:** Dialog with pre-filled title, Save / Cancel.

**Delete:** Confirm dialog before permanent deletion.

**Empty state:** Prompt to upload first track.

### Sign-in UX

After requesting magic link, replace form with inline "Check your email" message on the same `/sign-in` page; option to request another link.

Already-signed-in users visiting `/sign-in` redirect to `/library`.

### Playback page

**Metadata:** Title, duration, and listen count (e.g., "12 listens") — no upload date.

**Anonymous tracks:** Static expiry message at SSR (e.g. "This temporary track expires 10 minutes after upload" or relative text like "Uploaded 3 minutes ago · expires soon"). No live countdown timer.

**404:** Single generic message — "Track not found" — for invalid, deleted, and expired slugs.

**Player:** Custom UI (play/pause, seek scrubber, elapsed/total time). No volume control, no keyboard shortcuts for MVP. Spinner on play button while presigned stream URL loads. On countable play (fresh start from beginning, not yet counted this pass), fire-and-forget `POST` to increment listen count; track `listenCountedForPass` client-side, reset on `ended`.

**Mobile scrubber:** Same component; taller touch target via CSS padding.

### Open Graph

**Title:** Track name.

**Description:** Fixed — "Listen on throw.it".

**Image:** Single static branded `og:image` for all tracks (logo + "Audio on throw.it" or similar).

### Frontend architecture

**Server vs client:** Pragmatic split — Server Components by default; `"use client"` only for player, upload flow, forms, dialogs, clipboard actions.

**Data fetching:** Server Components for reads (library list, playback metadata SSR). Client components call `/api/...` for mutations; `router.refresh()` after rename/delete.

**Forms:** React Hook Form + Zod.

**Accessibility (MVP baseline):** Semantic HTML, visible focus states, dialog focus traps (shadcn), `aria-label` on icon-only buttons, sufficient color contrast in both themes.

**Responsive:** Mobile-first; all pages usable on phone.

## Prototype alignment notes

The Open Design prototypes (see **UI design references** above) supersede the earlier single-file wireframe review. They include all required states from that review: upload quota/limit errors, OGG format warning, playback loading/error/404, sign-in expired link, listen-count pluralization, theme dropdown, and destructive delete styling.

**Implementation reminders not visible in static HTML:**

- Listen increment: prefer optimistic UI update on countable play; server is source of truth on refresh (`playback.html` → `countable` state documents client rules).
- Playback titles: use display title (filename without extension), not raw filename with extension.
- Mobile library: prototype uses icon-only row actions; keep that pattern on narrow viewports.
- Anonymous success: optional note "Open Preview to see listen count" (no library for temp uploaders).

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

- Per-track OG artwork (dynamic preview images) — post-MVP; MVP uses static `og:image`
- Transcoding pipeline — post-MVP when "won't play on iPhone" becomes common
- CDN — add when global latency or storage egress costs warrant it
- Paid tiers with higher storage quotas — post-MVP monetization
