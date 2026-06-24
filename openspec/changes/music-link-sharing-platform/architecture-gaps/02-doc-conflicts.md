# Where the docs disagree

When two sources say different things, engineers pick one at random. That is how you get "works on my machine" behavior across environments.

Each row: what conflicts, where, and why it matters.

---

## Magic link reuse after first sign-in

| Source | Says |
|--------|------|
| `design.md` §5 | Links reusable within 15 minutes **until first successful sign-in** |
| `architecture.md` §6.4 | Same: until first successful sign-in |
| `endpoint-handlers.md` §3.2 | After sign-in, same link **may still work on another device** if within 15 minutes |
| `uploader-auth` spec | Scenario: same link on phone and laptop within 15 minutes both work |
| `tasks.md` §4.7 | "Until first successful sign-in" (matches design, not handlers) |

**The tension:** "Until first sign-in" sounds like one-shot invalidation. The phone + laptop scenario needs reuse after the first device already signed in.

**Pick one:**

- **A)** First successful sign-in invalidates the token everywhere (`used_at` set). Second device must request a new link.
- **B)** Token valid for full 15 minutes regardless of sign-ins. Simpler, slightly less secure, matches handler doc and auth spec scenario.

---

## Anonymous per-file size vs combined quota

| Source | Says |
|--------|------|
| `proposal.md`, `design.md` | 100 MB **combined** per IP for anonymous |
| `endpoint-handlers.md` §4.2 step 3 | Per-file validation **≤ 500 MB** (signed-in limit) |
| `anonymous-upload` spec | Combined quota only; no per-file cap stated |

**Example:** User with 0 anonymous tracks uploads a 200 MB file. Passes step 3 (500 MB check). Fails step 5 with **413** (storage cap). Error message may not say "anonymous max file size."

**Pick one:** Explicit anonymous per-file max (e.g. 100 MB), or cap at min(500, remaining quota) with clear error copy.

---

## Delete: hard remove vs soft delete

| Source | Says |
|--------|------|
| `track-management` spec | "Track record and stored audio file are **removed**" |
| `architecture.md`, `endpoint-handlers.md`, `tasks.md` §8.5 | **Soft delete** (`deleted_at`), R2 delete, slug retirement |

Playback behavior aligns (404 on share URL). Wording differs on whether the DB row survives.

**Pick one:** Update spec to say soft delete, or change implementation to hard delete (usually worse for audit/debug).

---

## Expired anonymous track 404 message

| Source | Says |
|--------|------|
| `design.md`, `tasks.md` §7.8 | Generic **"Track not found"** for invalid, deleted, and expired |
| `anonymous-upload` spec (expiry scenario) | 404 indicating track is **no longer available** (more specific) |

**Pick one:** Same generic message (privacy-friendly) or distinct copy for expired temp tracks (clearer for listeners).

---

## Anonymous expiry messaging on playback page

| Source | Says |
|--------|------|
| `shareable-playback` spec | **Static** text: "expires 10 minutes after upload" |
| `design.md` UX examples | Relative copy: "Uploaded 3 minutes ago · expires soon" |

Static text is misleading near end of TTL (says "10 minutes" when 2 minutes remain).

**Pick one:** Static only, relative only, or static with upload timestamp in SSR.

---

## Already signed-in on `/sign-in`

| Source | Says |
|--------|------|
| `design.md` | Redirect to `/library` |
| `uploader-auth` spec | Redirect **with message** indicating already signed in |

Minor UX gap: toast/banner copy not specified in design doc.

---

## Signed-in user on anonymous upload path

| Source | Says |
|--------|------|
| `design.md`, `tasks.md` §10.3 | Redirect `/upload/temp` → `/upload` |
| `anonymous-upload` spec | Not mentioned |

Not a contradiction, but capability spec alone is incomplete for routing behavior.

---

## Format warnings on anonymous upload

| Source | Says |
|--------|------|
| `audio-upload` spec | OGG (and browser-risky formats) warning before upload |
| `anonymous-upload` spec | References signed-in format rules; no explicit warning requirement |
| `endpoint-handlers.md` | Rejection paths only; no warning behavior |

**Pick one:** Same warnings on `/upload/temp`, or anonymous path skips warnings.

---

## Listen count display after play

| Source | Says |
|--------|------|
| `shareable-playback` spec | Server-side increment; SSR initial count |
| `design.md` | Optimistic UI update preferred |

Spec silent on whether playback page updates count without refresh.

---

## Concurrent signed-in + anonymous upload (same IP)

| Source | Says |
|--------|------|
| Signed-in concurrent limit | One in-progress session per **uploader_id** |
| Anonymous concurrent limit | One in-progress session per **IP** |

Nothing prevents same person (signed in) from also starting an anonymous upload from the same IP in parallel.

**Pick one:** Allow ( simpler ) or block cross-mode concurrent uploads.

---

## Doc precedence (meta)

No document defines which source wins when specs and handlers conflict. See [ARCHITECTURE-GAPS.md](ARCHITECTURE-GAPS.md) for a practical reading order.

**Recommendation:** The [home page](../index.md#source-of-truth) now includes a source-of-truth hierarchy. Update capability specs first when resolving conflicts, then `endpoint-handlers.md`.
