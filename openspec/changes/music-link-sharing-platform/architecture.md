# throw.it — technical architecture

Architect-facing overview of how the MVP works at runtime. For product scope, UX, and decision rationale, see `proposal.md` and `design.md`. For behavioral requirements, see `specs/`.

---

## 1. Purpose

throw.it is a link-sharing platform for audio professionals. Uploaders publish a track and receive a short URL; listeners open that URL and stream in the browser without an account.

The system supports two upload modes that share the same playback path. Signed-in uploaders get persistent storage and a library. Anonymous uploaders get a 10-minute temporary track with IP-based quotas.

Audio bytes never pass through the application server. Metadata lives in PostgreSQL; files live in S3-compatible object storage (Cloudflare R2 in production, MinIO locally).

---

## 2. System context

```mermaid
flowchart LR
  subgraph clients [Clients]
    Uploader[Uploader browser]
    Listener[Listener browser]
  end

  subgraph app [throw.it application]
    Next[Next.js 15 App Router]
    API[Internal API routes]
    Next --> API
  end

  subgraph data [External services]
    PG[(PostgreSQL)]
    R2[(Object storage)]
    Email[Email provider]
  end

  Uploader --> Next
  Listener --> Next
  API --> PG
  API --> R2
  API --> Email
  Uploader -.->|presigned PUT| R2
  Listener -.->|presigned GET| R2
```

The application is a single deployable unit: one Next.js monorepo serving pages (SSR) and internal `/api/*` routes. There is no public third-party API; all endpoints exist to support the web UI.

Listeners never authenticate. Uploaders authenticate only when using persistent upload or library features.

---

## 3. Runtime components

| Component | Role |
|-----------|------|
| **Next.js pages** | SSR for playback metadata and Open Graph; Server Components for library reads |
| **Client components** | Upload flow, audio player, forms, dialogs, clipboard actions |
| **API routes** | Auth, upload orchestration, stream URL issuance, listen increment, track mutations |
| **PostgreSQL** | Uploaders, sessions, tracks, upload sessions, magic links, retired slugs |
| **Object storage** | Audio file blobs keyed by `storage_key`; private bucket, presigned access only |
| **Email** | Magic link delivery (Resend in production, SMTP/Mailpit locally) |
| **Background jobs** | Expire anonymous tracks, sweep orphaned uploads, release abandoned upload sessions |

### Frontend split

Server Components are the default. Client boundaries are limited to interactive surfaces: upload progress, player, auth forms, rename/delete dialogs, and theme toggle.

Reads (library list, playback page metadata) happen in Server Components. Mutations call `/api/*` from the client, then `router.refresh()` where needed.

---

## 4. Data model

Six logical tables. Tracks are the central entity; upload sessions are a short-lived staging state before confirmation.

```mermaid
erDiagram
  uploaders ||--o{ tracks : owns
  uploaders ||--o{ sessions : has
  uploaders ||--o{ upload_sessions : initiates

  uploaders {
    uuid id PK
    string email UK
    timestamp created_at
  }

  tracks {
    uuid id PK
    string slug UK
    string title
    int duration_ms
    string format
    bigint file_size_bytes
    string storage_key
    uuid uploader_id FK "nullable"
    bool is_anonymous
    timestamp expires_at "nullable"
    int listen_count
    timestamp created_at
    timestamp deleted_at "nullable"
  }

  upload_sessions {
    uuid id PK
    string upload_id UK
    string storage_key
    uuid uploader_id FK "nullable"
    string ip_address
    bigint file_size_bytes
    string status
    timestamp created_at
    timestamp expires_at
  }

  sessions {
    uuid id PK
    uuid uploader_id FK
    string token
    timestamp expires_at
  }

  magic_links {
    uuid id PK
    string email
    string token
    timestamp expires_at
    timestamp used_at "nullable"
  }

  retired_slugs {
    string slug PK
    timestamp retired_at
  }
```

### Entity rules

**Tracks** — Created only after upload confirmation. `slug` is an 8-character random identifier exposed at `/t/{slug}`. Slugs are retired permanently on delete or anonymous expiry and never reassigned.

**Upload sessions** — Hold in-progress uploads for up to 15 minutes. Quota and concurrent-upload limits apply to active sessions. Orphaned storage keys without a matching track are removed by the sweeper job.

**Anonymous tracks** — `uploader_id` is null, `is_anonymous` is true, `expires_at` is set to 10 minutes after confirm. IP address is captured for quota enforcement.

**Soft delete** — Signed-in track deletion sets `deleted_at`; the playback page returns 404. The R2 object is removed and the slug is retired.

---

## 5. API surface

All routes are internal to the application. Authentication uses an HTTP-only session cookie resolved server-side.

| Method | Route | Auth | Purpose |
|--------|-------|------|---------|
| `POST` | `/api/auth/magic-link` | — | Issue magic link email |
| `GET` | `/auth/verify` | — | Validate token, create session, redirect to `/library` |
| `POST` | `/api/upload` | Session | Start signed-in upload; return presigned PUT + `upload_id` |
| `POST` | `/api/upload/temp` | — | Start anonymous upload; return presigned PUT + `upload_id` |
| `POST` | `/api/upload/confirm` | Session or IP | Promote upload session to track; return share URL |
| `GET` | `/api/tracks/[slug]/stream` | — | Issue presigned GET URL (refresh on demand) |
| `POST` | `/api/tracks/[slug]/listen` | — | Increment `listen_count` |
| `PATCH` | `/api/tracks/[id]` | Session | Rename track (ownership check) |
| `DELETE` | `/api/tracks/[id]` | Session | Soft-delete track, remove R2 object, retire slug |

Sign-out is a route handler that deletes the session row and clears the cookie.

### Quota enforcement (upload initiation)

| Mode | Limits checked at `POST /api/upload` or `/api/upload/temp` |
|------|-------------------------------------------------------------|
| Signed-in | 500 MB per file; 5 GB total per uploader; one in-progress upload session |
| Anonymous | 3 active tracks per IP; 100 MB combined per IP; one in-progress upload session |

Confirmed tracks count toward quota. In-progress upload sessions block further uploads for 15 minutes.

---

## 6. Core flows

### 6.1 Signed-in upload

```mermaid
sequenceDiagram
  actor U as Uploader
  participant UI as Upload page
  participant API as API routes
  participant DB as PostgreSQL
  participant R2 as Object storage

  U->>UI: Select file, optional title
  UI->>API: POST /api/upload
  API->>DB: Check quota, create upload_session
  API-->>UI: presigned PUT URL + upload_id
  UI->>R2: PUT file (direct, with progress)
  UI->>API: POST /api/upload/confirm (upload_id, duration_ms)
  API->>DB: Create track row with new slug
  API-->>UI: Share URL /t/{slug}
```

The client uploads directly to R2 via XMLHttpRequest. Duration is reported by the browser at confirm time; no server-side audio probing.

Confirm is idempotent per `upload_id` (same-ticket retry without re-uploading the file).

### 6.2 Anonymous upload

The flow matches signed-in upload except initiation hits `POST /api/upload/temp` without a session. Confirm sets `expires_at` to 10 minutes from confirmation and derives the title from the filename.

Signed-in users visiting `/upload/temp` are redirected to `/upload`.

### 6.3 Playback and streaming

```mermaid
sequenceDiagram
  actor L as Listener
  participant Page as /t/[slug] SSR
  participant Player as Client player
  participant API as API routes
  participant DB as PostgreSQL
  participant R2 as Object storage

  L->>Page: Open share URL
  Page->>DB: Load track metadata
  Page-->>L: HTML + title, duration, listen count

  L->>Player: Press play
  Player->>API: GET /api/tracks/[slug]/stream
  API->>DB: Validate slug (active, not expired)
  API-->>Player: Presigned GET URL
  Player->>R2: Stream audio (HTTP range requests)

  Note over Player: On play from start (currentTime < 0.5s)
  Player->>API: POST /api/tracks/[slug]/listen
  API->>DB: Increment listen_count

  Note over Player: On URL expiry during session
  Player->>API: GET /api/tracks/[slug]/stream
  API-->>Player: Fresh presigned GET URL
```

Playback metadata is server-rendered for fast first paint and Open Graph tags. The audio element streams from R2, not through the app server.

Presigned URL TTL is 1–4 hours for signed-in tracks. For anonymous tracks, the URL is capped at `expires_at`.

### 6.4 Magic link authentication

```mermaid
sequenceDiagram
  actor U as Uploader
  participant UI as /sign-in
  participant API as API routes
  participant DB as PostgreSQL
  participant Mail as Email

  U->>UI: Enter email
  UI->>API: POST /api/auth/magic-link
  API->>DB: Store token (15 min expiry)
  API->>Mail: Send link to /auth/verify?token=…
  API-->>UI: 200

  U->>API: GET /auth/verify?token=…
  API->>DB: Validate token, create session (24 h)
  API-->>U: Set cookie, redirect /library
```

Magic links are reusable within the 15-minute window until first successful sign-in. Sessions last 24 hours and allow multiple devices.

---

## 7. Background jobs

Three cleanup responsibilities run on a schedule (Vercel cron in production, CLI scripts locally).

```mermaid
flowchart TD
  Cron[Cron scheduler] --> Expire[expire-tracks]
  Cron --> Sweep[sweep-orphans]
  Cron --> Abandon[expire upload_sessions]

  Expire -->|past expires_at| DelTrack[Delete anonymous tracks]
  DelTrack --> DelR2[Remove R2 objects]
  DelTrack --> Retire[Retire slugs]

  Sweep -->|no matching track or session| OrphanR2[Delete orphan R2 objects]

  Abandon -->|older than 15 min| Release[Mark sessions expired]
  Release --> Unblock[Release concurrent-upload blocks]
```

| Job | Trigger | Effect |
|-----|---------|--------|
| **expire-tracks** | Tracks past `expires_at` | Delete row, remove R2 object, retire slug, free IP quota |
| **sweep-orphans** | R2 keys without track or active session | Delete orphan objects |
| **expire upload_sessions** | Sessions older than 15 minutes | Mark expired; unblock uploader/IP for new uploads |

Signed-in track deletion is synchronous in the `DELETE` API route (not deferred to cron).

---

## 8. Architectural constraints

These boundaries shape every design choice in the MVP.

| Constraint | Implication |
|------------|-------------|
| No transcoding | Browser-native decode only; format warnings at upload, errors at playback |
| No CDN | Single-region R2; acceptable latency at early scale |
| No public API | All integration is through the web UI |
| Private bucket | All file access via short-lived presigned URLs |
| Serverless app host | Large files bypass the app server; no server-side duration probing |
| $0 MVP budget | Free tiers for compute, database, storage, and email |

For full decision rationale and rejected alternatives, see `design.md` § Decisions. For per-capability requirements, see `specs/*/spec.md`.
