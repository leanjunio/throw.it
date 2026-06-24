# Implementation blockers

These are gaps where the docs describe behavior that the current data model or API contract cannot support. You need a doc or schema change before coding.

---

## 1. Filename not persisted on upload sessions

**What the docs say**

- Initiation accepts `{ filename, fileSizeBytes, contentType, title? }` (`endpoint-handlers.md` §4.1, §4.2).
- Confirm derives title from "the session's original filename" when no title is provided (`endpoint-handlers.md` §4.3).
- Anonymous uploads always derive title from filename (`anonymous-upload` spec, `design.md`).

**What the schema has**

`upload_sessions` columns: `id`, `upload_id`, `storage_key`, `uploader_id`, `ip_address`, `file_size_bytes`, `status`, `created_at`, `expires_at`. No filename.

**Why it matters**

If the user refreshes mid-upload, or confirm runs without the client resending title/filename, the server has no way to derive the display title.

**Suggested fix**

Add `original_filename text not null` to `upload_sessions`. Set it at initiation. Use it at confirm for title stem extraction.

---

## 2. Anonymous IP not on tracks table

**What the docs say**

- Anonymous quota: 3 active tracks and 100 MB combined **per IP** (`proposal.md`, `architecture.md` §5).
- Entity rules: "IP address is captured for quota enforcement" on anonymous tracks (`architecture.md` §4).
- `tasks.md` §6.2: "IP is stored on `upload_sessions` and anonymous `tracks`."

**What the schema has**

- `upload_sessions.ip_address` — yes
- `tracks` — no `ip_address` column in ER diagram or `tasks.md` §3.2

**Why it matters**

Quota checks at **initiation** can use in-progress sessions plus confirmed tracks. Counting confirmed anonymous tracks per IP requires knowing which IP owns each track after the upload session is `confirmed`. Unless you join through something else (you cannot today), quota enforcement breaks after confirm.

**Suggested fix**

Add nullable `ip_address` on `tracks`, set for anonymous confirms only. Or document and implement an explicit join strategy (none exists in current schema).

---

## 3. Magic link `used_at` is undefined

**What the schema has**

`magic_links.used_at` nullable timestamp.

**What the docs say**

Nothing about when to set it or whether it blocks reuse.

**Why it matters**

You cannot implement magic link invalidation without knowing if `used_at` means "first click," "first successful session," or "never used, documentation leftover."

**Suggested fix**

Define in `design.md` and `endpoint-handlers.md`:

- When `used_at` is set
- Whether setting it blocks further GETs on that token
- How this interacts with multi-device sign-in

---

## 4. Storage key format not specified

**What the docs say**

Tracks and upload sessions have `storage_key`. R2 holds blobs keyed by this value.

**What is missing**

- Path prefix (e.g. `uploads/{uuid}` vs flat UUID)
- Whether anonymous and signed-in keys differ
- Whether keys embed uploader id for sweeper efficiency

**Why it matters**

Orphan sweeper must find R2 objects without matching DB rows. Without a prefix convention, full bucket listing is expensive and risky on R2.

**Suggested fix**

One line in `architecture.md`: e.g. `storage_key = "{upload_id}"` or `uploads/{uuid}`.

---

## 5. Slug alphabet not fully pinned

**What the docs say**

8-character random slug from a "62-character alphabet" (`design.md`, `architecture.md`).

**What is missing**

Exact character set: `a-zA-Z0-9`? Exclude ambiguous `0/O`, `l/1`? Case sensitivity on lookup?

**Why it matters**

Collision retry logic and URL sharing (case in path) depend on this.

**Suggested fix**

Document exact alphabet and confirm slugs are case-sensitive in routing.

---

## 6. No library read specification

**What the docs say**

- Library page shows title, duration, date, listens, actions (`track-management` spec).
- "Server Components for library reads" (`architecture.md` §3).
- Sort: most recent first.

**What is missing**

- Sort field: `created_at` vs confirm time?
- Pagination or max rows?
- Which fields are returned to the UI?
- No dedicated API route; implied direct DB query in Server Component.

**Why it matters**

Fine for MVP with small libraries. Becomes a performance and consistency question as uploaders approach the 5 GB cap (many tracks).

**Suggested fix**

Short subsection in `architecture.md` or `endpoint-handlers.md`: query shape, sort, no pagination for MVP.

---

## 7. MIME type and extension validation map

**What the docs say**

Allowed: MP3, WAV, FLAC, AAC, OGG. Check extension and MIME type.

**What is missing**

- Full extension list (`.mp3`, `.wav`, `.wave`, `.flac`, `.ogg`, `.m4a`, `.aac`?)
- MIME map per extension
- Policy when extension and MIME disagree
- Magic-byte validation (explicitly rejected in `design.md` for MVP, but not repeated in specs)

**Why it matters**

Engineers will invent incompatible validation rules across initiation and confirm.

**Suggested fix**

Table in `endpoint-handlers.md`: extension → allowed MIME types → internal `format` enum value.

---

## 8. Server does not verify uploaded file size

**What the docs say**

Initiation takes client-reported `fileSizeBytes`. Confirm does HEAD on R2 for existence, not size.

**Why it matters**

Malicious or buggy clients can under-report size, bypass quota at initiation, then upload a larger object. Account cap and anonymous 100 MB cap can be exceeded.

**Suggested fix (product decision)**

Either accept client trust for MVP (document the risk) or HEAD R2 at confirm and compare `Content-Length` to declared size and quota.

---

## 9. Confirm step 2 vs idempotency (handler doc bug)

**Location:** `endpoint-handlers.md` §4.3

Step 2 treats "already confirmed" as **404**. Idempotency section and diagram return **200** with existing slug.

This is a documentation bug, not an architectural choice, but implementers reading step-by-step will build the wrong behavior.

**Fix:** Already-confirmed → load existing track by `upload_sessions` → return 200.
