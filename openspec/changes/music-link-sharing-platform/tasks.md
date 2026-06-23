## UI design references

When building frontend pages, use the Open Design prototypes as the visual and UX source of truth:

`/Users/leanjunio/Documents/projects/open-design/.od/projects/c5e34f64-b0b3-40ad-a5ab-b55822522dbf`

Open `index.html` in a browser for the route index. See `design.md` → **UI design references** for the route-to-file mapping and state variants. Shared tokens live in `css/shared.css`.

## Task format

Each task is **SMART**: specific scope, measurable criteria, achievable in one session, relevant to a spec in `specs/`, and testable without ambiguity.

**Done when** criteria are listed as bullets under each task. Every bullet must pass before the task is complete.

---

## 1. Local development environment

- [ ] **1.1** Add `docker-compose.yml` with Postgres 16, MinIO, and Mailpit
  - **Done when:**
    - `docker compose up -d` starts all three services healthy
    - Postgres accepts connections on `localhost:5432`
    - MinIO API is on `localhost:9000` and console on `localhost:9001`
    - `MINIO_SERVER_URL=http://localhost:9000` is set
    - Mailpit SMTP is on `localhost:1025` and web UI on `localhost:8025`
    - Named volumes persist data across restarts

- [ ] **1.2** Add MinIO bucket bootstrap (bucket creation + CORS)
  - **Done when:**
    - A compose init script or documented one-time `mc` command creates the `throwit` bucket
    - CORS allows origin `http://localhost:3000` with methods `GET`, `PUT`, `HEAD` and headers `*`
    - A presigned PUT from localhost succeeds from the browser

- [ ] **1.3** Document local setup in README
  - **Done when:**
    - README lists prerequisites (Docker, Node 20+)
    - README covers `docker compose up -d`, copy `.env.example` → `.env.local`, run migrations, and `pnpm dev`
    - README documents local URLs for Postgres, MinIO console, and Mailpit inbox
    - A new developer can reach `http://localhost:3000` following only the README

## 2. Project scaffolding

- [ ] **2.1** Initialize Next.js 15 app with TypeScript, Tailwind CSS, shadcn/ui, Geist font, and App Router
  - **Done when:**
    - `pnpm dev` serves the app at `localhost:3000`
    - Tailwind and shadcn/ui are configured
    - Geist Sans and Geist Mono load
    - Design tokens from `css/shared.css` in the prototypes are mapped to Tailwind theme values

- [ ] **2.2** Configure ESLint, Prettier, and environment variable schema
  - **Done when:**
    - `pnpm lint` and `pnpm format:check` pass on a clean tree
    - `.env.example` documents every required variable (`DATABASE_URL`, S3/R2 endpoint and credentials, bucket name, email/SMTP settings, `APP_URL`, session secret) with local Docker defaults
    - Env validation fails fast at startup when a required variable is missing

- [ ] **2.3** Set up Drizzle ORM with PostgreSQL connection and migration tooling
  - **Done when:**
    - Drizzle config points at `DATABASE_URL`
    - `pnpm db:generate` and `pnpm db:migrate` scripts exist
    - A test query against local Postgres succeeds via the Drizzle client

- [ ] **2.4** Add S3-compatible SDK and storage client helpers
  - **Done when:**
    - `@aws-sdk/client-s3` and `@aws-sdk/s3-request-presigner` are installed
    - A shared client reads endpoint, region, credentials, and bucket from env
    - Helpers can generate presigned PUT and GET URLs against local MinIO

- [ ] **2.5** Add email delivery for magic links (Resend in prod, SMTP/Mailpit locally)
  - **Done when:**
    - A `sendMagicLinkEmail(to, url)` helper sends via Resend when `RESEND_API_KEY` is set
    - The same helper sends via SMTP (Mailpit on `localhost:1025`) in local dev
    - A test send appears in Mailpit at `localhost:8025`

- [ ] **2.6** Configure theme support (next-themes: Light / Dark / System)
  - **Done when:**
    - `next-themes` wraps the app
    - Default theme is System
    - Preference persists in localStorage
    - A nav theme dropdown offers Light, Dark, and System
    - Both themes render correctly on a sample page

## 3. Database schema

- [ ] **3.1** Define `uploaders` table
  - **Done when:**
    - Drizzle schema has `id`, `email` (unique), `created_at`
    - Migration applies cleanly to local Postgres

- [ ] **3.2** Define `tracks` table
  - **Done when:**
    - Schema has `id`, `slug`, `title`, `duration_ms`, `format`, `file_size_bytes`, `storage_key`, nullable `uploader_id`, `is_anonymous`, nullable `expires_at`, `listen_count` (default 0), `created_at`, nullable `deleted_at`
    - Migration applies cleanly

- [ ] **3.3** Define `magic_links` table
  - **Done when:**
    - Schema has `id`, `email`, `token`, `expires_at`, nullable `used_at`
    - Migration applies cleanly

- [ ] **3.4** Define `sessions` table
  - **Done when:**
    - Schema has `id`, `uploader_id` (FK), `token`, `expires_at`
    - Migration applies cleanly

- [ ] **3.5** Define `upload_sessions` table
  - **Done when:**
    - Schema has `id`, `upload_id`, `storage_key`, nullable `uploader_id`, `ip_address`, `file_size_bytes`, `status`, `created_at`, `expires_at`
    - Migration applies cleanly

- [ ] **3.6** Enforce slug retirement (never reuse)
  - **Done when:**
    - A `retired_slugs` table (`slug`, `retired_at`) exists, or an equivalent constraint prevents any slug from being assigned twice across all tracks ever created
    - Migration applies cleanly

- [ ] **3.7** Run initial migration and verify schema
  - **Done when:**
    - `pnpm db:migrate` succeeds against local Postgres
    - All six tables exist with expected columns
    - `pnpm db:studio` (or `\d` in psql) confirms the schema matches `design.md`

## 4. Uploader authentication

- [ ] **4.1** Build sign-in page with email input and "Send magic link" action
  - **Done when:**
    - `/sign-in` renders email field and submit button matching `sign-in.html` (`email` state)
    - Valid email submission shows `check-email` state inline on the same page

- [ ] **4.2** Implement magic link generation and email send API
  - **Done when:**
    - `POST /api/auth/magic-link` validates email, stores a token with 15-minute expiry in `magic_links`, sends the link via the email helper, and returns 200
    - The link URL is visible in Mailpit locally

- [ ] **4.3** Implement magic link verification and session creation
  - **Done when:**
    - `GET /auth/verify?token=…` validates the token, creates a `sessions` row with 24-hour expiry, sets an HTTP-only session cookie, and redirects to `/library`
    - Invalid or expired tokens show the `expired` state UI from `sign-in.html`

- [ ] **4.4** Build session helper to resolve current uploader
  - **Done when:**
    - Server-side helper reads the session cookie, loads the uploader, and returns `null` for missing, expired, or invalid sessions
    - Helper is usable from API routes and Server Components

- [ ] **4.5** Implement sign-out
  - **Done when:**
    - Sign-out route deletes the session row, clears the cookie, and redirects to `/`
    - A subsequent request to `/library` redirects to `/sign-in`

- [ ] **4.6** Handle expired magic links in UI
  - **Done when:**
    - Visiting `/auth/verify` with an expired token renders the `expired` state from `sign-in.html` with a link to request a new one

- [ ] **4.7** Support magic link reuse and signed-in redirect
  - **Done when:**
    - The same magic link works on multiple devices within 15 minutes until first successful sign-in
    - A user with a valid session visiting `/sign-in` redirects to `/library` without sending a new email

## 5. Signed-in audio upload

- [ ] **5.1** Build signed-in upload page UI
  - **Done when:**
    - `/upload` has drag-and-drop zone, file picker, optional title input, Upload button, and progress bar matching `upload.html` (`interactive` state)
    - Unauthenticated visitors redirect to `/sign-in`

- [ ] **5.2** Implement signed-in upload initiation API
  - **Done when:**
    - `POST /api/upload` (authenticated) validates format (MP3, WAV, FLAC, AAC, OGG), enforces 500 MB per-file and 5 GB account cap, blocks concurrent in-progress `upload_sessions`, and returns presigned PUT URL and `upload_id`
    - Account-cap breach returns an error surfaced in the `quota` state UI

- [ ] **5.3** Implement client-side direct upload with progress
  - **Done when:**
    - Selected file uploads via XMLHttpRequest to the presigned URL
    - Progress bar updates 0–100%
    - Upload errors show a retryable message

- [ ] **5.4** Implement upload confirm API
  - **Done when:**
    - `POST /api/upload/confirm` accepts `upload_id` and browser-reported `duration_ms`, promotes `upload_session` to a `tracks` row with a new 8-char slug, and returns the share URL
    - Object exists in MinIO/R2

- [ ] **5.5** Support same-ticket retry on confirm failure
  - **Done when:**
    - Retrying confirm with the same `upload_id` succeeds without re-uploading the file
    - A second confirm does not create a duplicate track

- [ ] **5.6** Show post-upload success panel
  - **Done when:**
    - After confirm, the upload page shows share link, copy button, Preview link to `/t/[slug]`, and Upload another control matching `upload.html` success panel

- [ ] **5.7** Add client-side pre-upload validation
  - **Done when:**
    - Unsupported extensions and files over 500 MB are rejected before upload starts with clear inline errors

- [ ] **5.8** Show format compatibility warnings
  - **Done when:**
    - Selecting OGG (and other browser-risky formats per spec) shows the warning banner from `upload.html` before upload
    - Upload is still allowed

- [ ] **5.9** Block concurrent uploads per user
  - **Done when:**
    - A second upload attempt while an `upload_session` is in-progress (within 15-minute window) is rejected with a clear message

## 6. Anonymous audio upload

- [ ] **6.1** Build anonymous upload page UI
  - **Done when:**
    - `/upload/temp` has drag-and-drop, file picker, Upload button, no title field, and 10-minute expiry messaging matching `upload-temp.html` (`interactive` state)
    - Signed-in users redirect to `/upload`

- [ ] **6.2** Implement IP detection for quota enforcement
  - **Done when:**
    - Server extracts client IP from `X-Forwarded-For` in production and falls back to a dev-safe header or connection IP locally
    - IP is stored on `upload_sessions` and anonymous `tracks`

- [ ] **6.3** Enforce anonymous IP limits
  - **Done when:**
    - API rejects uploads when IP has 3 active anonymous tracks, 100 MB combined active storage, or an in-progress upload session
    - UI shows `ip-tracks` and `ip-storage` error states from `upload-temp.html`

- [ ] **6.4** Implement anonymous upload initiation API
  - **Done when:**
    - Unauthenticated `POST /api/upload/temp` validates format and size, returns presigned PUT URL and `upload_id` without requiring auth

- [ ] **6.5** Set anonymous track expiry on confirm
  - **Done when:**
    - Confirm sets `expires_at` to 10 minutes from confirm time
    - Confirm sets `is_anonymous = true` and `uploader_id = null`

- [ ] **6.6** Show anonymous post-upload success panel
  - **Done when:**
    - Success panel shows share link, static expiry warning, copy button, Preview link, and Upload another matching `upload-temp.html`

- [ ] **6.7** Release IP quota on anonymous expiry
  - **Done when:**
    - After cleanup deletes an expired anonymous track, the IP can upload again within the 3-track and 100 MB limits

## 7. Shareable playback

- [ ] **7.1** Build playback page with SSR metadata
  - **Done when:**
    - `/t/[slug]` server-renders title, duration, and listen count for valid tracks matching `playback.html` (`playing`, `anonymous`, `pluralization` states)

- [ ] **7.2** Implement presigned stream URL API with refresh-on-demand
  - **Done when:**
    - `GET /api/tracks/[slug]/stream` returns a time-limited presigned GET URL
    - Signed-in tracks TTL 1–4 hours; anonymous tracks capped at `expires_at`
    - Expired or deleted slugs return 404

- [ ] **7.3** Build custom audio player
  - **Done when:**
    - Player has play/pause, seek scrubber, elapsed/total time, play-button spinner while URL loads, and automatic stream URL refresh on expiry matching `playback.html` (`loading` state)
    - No volume control or keyboard shortcuts

- [ ] **7.4** Implement listen increment API
  - **Done when:**
    - `POST /api/tracks/[slug]/listen` atomically increments `listen_count` for valid active slugs
    - Returns 404 for invalid, deleted, or expired slugs

- [ ] **7.5** Implement listen-count client rules
  - **Done when:**
    - Player fires increment on play from `currentTime < 0.5` when not yet counted this pass
    - Does not count pause/resume or scrub-to-start mid-pass
    - Resets `listenCountedForPass` on `ended`
    - Counts again after natural end and replay (`countable` state)

- [ ] **7.6** Display listen count with correct pluralization
  - **Done when:**
    - Playback page shows "0 listens", "1 listen", and "N listens" correctly

- [ ] **7.7** Add Open Graph meta tags
  - **Done when:**
    - Playback page `<head>` includes `og:title` (track name), `og:description` ("Listen on throw.it"), and a static `og:image`
    - Link previews render correctly in a social debugger

- [ ] **7.8** Build generic 404 playback page
  - **Done when:**
    - Invalid, deleted, and expired slugs all render "Track not found" matching `playback.html` (`404` state)

- [ ] **7.9** Show static expiry message on anonymous tracks
  - **Done when:**
    - Anonymous playback pages show SSR expiry text (e.g. "This temporary track expires 10 minutes after upload")
    - No live countdown timer

- [ ] **7.10** Show graceful playback decode error
  - **Done when:**
    - When the browser cannot decode the format, the player shows the error state from `playback.html` (`error` state) instead of failing silently

## 8. Track management (signed-in only)

- [ ] **8.1** Build library page
  - **Done when:**
    - `/library` renders a table with Title, Duration, Date, Listens, and Actions matching `library.html` (`populated` state)
    - Unauthenticated visitors redirect to `/sign-in`

- [ ] **8.2** Display storage usage
  - **Done when:**
    - Library shows used vs 5 GB cap (e.g. "2.3 GB of 5 GB used") computed from sum of `file_size_bytes` for the uploader's active tracks

- [ ] **8.3** Implement copy-link action
  - **Done when:**
    - Copy link button writes `/t/[slug]` to clipboard and shows a Sonner toast confirmation

- [ ] **8.4** Implement rename
  - **Done when:**
    - Rename dialog (pre-filled title, Save/Cancel) and `PATCH /api/tracks/[id]` update title with ownership check
    - `router.refresh()` reflects the new title

- [ ] **8.5** Implement delete
  - **Done when:**
    - Confirm dialog and `DELETE /api/tracks/[id]` soft-delete the track, remove the R2 object, retire the slug, and free quota
    - Destructive button styling matches `library.html`

- [ ] **8.6** Add empty library state
  - **Done when:**
    - Uploaders with zero tracks see the empty state from `library.html` with a prompt to upload

- [ ] **8.7** Add Upload action on library page
  - **Done when:**
    - An Upload button/link navigates to `/upload`

## 9. Background cleanup jobs

- [ ] **9.1** Implement expired anonymous track cleanup
  - **Done when:**
    - A `pnpm cron:expire-tracks` script (or equivalent) deletes tracks past `expires_at`, removes their R2 objects, retires slugs, and logs count deleted
    - Script is runnable locally against Docker services

- [ ] **9.2** Implement orphaned upload sweeper
  - **Done when:**
    - A `pnpm cron:sweep-orphans` script deletes R2 objects with no matching `tracks` or active `upload_sessions` row and logs count deleted

- [ ] **9.3** Retire slugs on deletion and expiry
  - **Done when:**
    - Slug retirement runs as part of delete and anonymous expiry cleanup
    - A retired slug cannot be assigned to a new track

- [ ] **9.4** Expire abandoned upload sessions
  - **Done when:**
    - Cleanup marks `upload_sessions` older than 15 minutes as expired
    - Concurrent-upload blocks are released for that IP or uploader

## 10. Landing and navigation

- [ ] **10.1** Build public landing page
  - **Done when:**
    - `/` explains persistent vs temporary upload modes with CTAs to `/upload` and `/upload/temp` matching `landing.html`

- [ ] **10.2** Add root app shell and nav
  - **Done when:**
    - Every page shares a top nav with wordmark (links to `/`), Library link (signed-in only), theme toggle, and Sign in / Sign out
    - No footer; matches prototype nav pattern

- [ ] **10.3** Protect authenticated routes
  - **Done when:**
    - `/library` and `/upload` redirect unauthenticated users to `/sign-in`
    - Signed-in users visiting `/upload/temp` redirect to `/upload`

- [ ] **10.4** Keep anonymous upload public
  - **Done when:**
    - `/upload/temp` is reachable without authentication for signed-out users

## 11. Deployment and verification

- [ ] **11.1** Configure Vercel Hobby deployment
  - **Done when:**
    - Project deploys to Vercel on push
    - Production env vars are set for Neon, R2, Resend, `APP_URL`, and session secret
    - Production build succeeds

- [ ] **11.2** Provision production services
  - **Done when:**
    - Neon Postgres database exists with migrations applied
    - Cloudflare R2 bucket exists with production CORS
    - Resend domain is verified and sending

- [ ] **11.3** Configure Vercel cron for cleanup jobs
  - **Done when:**
    - `vercel.json` cron triggers expire-tracks and sweep-orphans on schedule
    - A manual cron invocation succeeds in production logs

- [ ] **11.4** Run end-to-end smoke test
  - **Done when:**
    - In production (or full local Docker stack): anonymous upload → share → play (listen count increments) → expire
    - Sign in → upload → play → library shows listens → rename → delete → slug returns 404
    - All steps pass without manual DB edits
