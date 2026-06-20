## 1. Project scaffolding

- [ ] 1.1 Initialize Next.js 15 app with TypeScript, Tailwind CSS, and App Router
- [ ] 1.2 Configure ESLint, Prettier, and environment variable schema (`.env.example`)
- [ ] 1.3 Set up Drizzle ORM with PostgreSQL connection and migration tooling
- [ ] 1.4 Add S3-compatible SDK (Cloudflare R2) and configure bucket/client helpers
- [ ] 1.5 Add Resend email SDK for magic link delivery

## 2. Database schema

- [ ] 2.1 Define `uploaders` table (id, email, created_at)
- [ ] 2.2 Define `tracks` table (id, slug, title, duration_ms, format, file_size_bytes, storage_key, uploader_id nullable, is_anonymous, expires_at nullable, created_at, deleted_at)
- [ ] 2.3 Define `magic_links` table (id, email, token, expires_at, used_at)
- [ ] 2.4 Define `sessions` table (id, uploader_id, token, expires_at)
- [ ] 2.5 Define `upload_sessions` table (id, upload_id, storage_key, uploader_id nullable, ip_address, file_size_bytes, status, created_at, expires_at)
- [ ] 2.6 Define `retired_slugs` table (slug, retired_at) or enforce via unique constraint on all slugs ever used
- [ ] 2.7 Run initial migration and verify schema in local Postgres

## 3. Uploader authentication

- [ ] 3.1 Build sign-in page with email input and "Send magic link" action
- [ ] 3.2 Implement API route to generate magic link token, store it, and send email via Resend
- [ ] 3.3 Implement magic link verification route that creates a session (24-hour expiry) and sets HTTP-only cookie
- [ ] 3.4 Build session middleware/helper to resolve current uploader from cookie
- [ ] 3.5 Implement sign-out route that invalidates session and clears cookie
- [ ] 3.6 Handle expired magic links with clear error UI
- [ ] 3.7 Allow magic link reuse within 15-minute window; redirect already-signed-in users to library

## 4. Signed-in audio upload

- [ ] 4.1 Build signed-in upload page UI with file picker, optional title input, and progress bar
- [ ] 4.2 Implement API route to validate auth, file format, size (500 MB), and 5 GB account quota; return presigned R2 PUT URL and upload_id
- [ ] 4.3 Implement client-side direct upload to R2 with progress tracking
- [ ] 4.4 Implement upload confirm API route: accept browser-reported duration, promote upload_session to track, generate slug, create track record
- [ ] 4.5 Support same-ticket retry on confirm failure (reuse upload_id without re-uploading)
- [ ] 4.6 Display share link to uploader immediately after successful upload
- [ ] 4.7 Add client-side validation for supported formats and 500 MB size limit before upload starts
- [ ] 4.8 Show format compatibility warnings for risky formats (e.g., OGG)
- [ ] 4.9 Block concurrent uploads per user while an upload_session is in-progress (15-min timeout)

## 5. Anonymous audio upload

- [ ] 5.1 Build anonymous upload UI with clear 10-minute expiry messaging
- [ ] 5.2 Implement IP detection via X-Forwarded-For for quota enforcement
- [ ] 5.3 Enforce anonymous limits: 3 active tracks per IP, 100 MB combined per IP, 1 upload at a time
- [ ] 5.4 Implement anonymous upload API route with presigned R2 PUT URL and upload_id
- [ ] 5.5 Set expires_at to 10 minutes from confirm; no uploader_id on track record
- [ ] 5.6 Display share link with countdown/expiry warning after successful anonymous upload
- [ ] 5.7 Release IP upload slot and storage quota when TTL track expires and is deleted

## 6. Shareable playback

- [ ] 6.1 Build playback page at `/t/[slug]` with SSR for track metadata
- [ ] 6.2 Implement API route to generate time-limited presigned R2 GET URL with refresh-on-demand
- [ ] 6.3 Build audio player component with play/pause, seek scrubber, duration display, and stream URL refresh
- [ ] 6.4 Add Open Graph meta tags (title, description, type) to playback page for link previews
- [ ] 6.5 Build 404 page for invalid, deleted, or expired track slugs
- [ ] 6.6 Show expiry countdown on anonymous track playback pages
- [ ] 6.7 Show graceful playback error when browser cannot decode the audio format

## 7. Track management (signed-in only)

- [ ] 7.1 Build library page at `/library` listing uploader's tracks (title, duration, date, share link)
- [ ] 7.2 Display storage usage (e.g., "2.3 GB of 5 GB used")
- [ ] 7.3 Implement "Copy link" button with clipboard API and confirmation toast
- [ ] 7.4 Implement rename track API route with ownership check
- [ ] 7.5 Implement delete track API route with ownership check, R2 object removal, slug retirement, and quota update
- [ ] 7.6 Add empty state UI for uploaders with no tracks
- [ ] 7.7 Add "Upload" action on library page linking to signed-in upload flow

## 8. Background cleanup jobs

- [ ] 8.1 Implement cron/job to delete expired anonymous tracks (past expires_at) and their R2 objects
- [ ] 8.2 Implement sweeper job to delete orphaned R2 objects with no matching track record
- [ ] 8.3 Retire slugs on track deletion and anonymous expiry (never reuse)
- [ ] 8.4 Expire abandoned upload_sessions after 15 minutes and release concurrent upload blocks

## 9. Landing and navigation

- [ ] 9.1 Build public landing page explaining both upload modes (persistent vs temporary) with CTAs
- [ ] 9.2 Add app shell with navigation (logo, library link for auth'd users, sign in/out)
- [ ] 9.3 Protect `/library` and signed-in `/upload` routes; redirect unauthenticated users to sign-in
- [ ] 9.4 Keep anonymous upload path accessible without authentication

## 10. Local development and deployment

- [ ] 10.1 Add Docker Compose for local Postgres and MinIO (S3-compatible)
- [ ] 10.2 Document local setup steps in README
- [ ] 10.3 Configure Vercel Hobby deployment with production environment variables
- [ ] 10.4 Provision production Neon Postgres, Cloudflare R2 bucket, and Resend domain
- [ ] 10.5 Configure Vercel cron for cleanup jobs (expired tracks, orphan sweeper)
- [ ] 10.6 Run end-to-end smoke test: anonymous upload → share → play → expire; sign in → upload → rename → delete → 404
