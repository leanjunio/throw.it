# Architecture gaps and ambiguities

This is a solution-architect review of all throw.it documentation in `openspec/changes/music-link-sharing-platform/`. It lists places where the docs are unclear, incomplete, or contradict each other.

**Who this is for:** You, as a software engineer learning how to read specs like an architect. The goal is not to criticize the docs. It is to show where real products still leave room for interpretation, and what kinds of questions architects ask before anyone writes code.

**What was reviewed:**

| Layer | Files |
|-------|-------|
| Overview | `index.md`, `proposal.md`, `design.md` |
| Architecture | `architecture.md`, `endpoint-handlers.md` |
| Capabilities | Five specs under `specs/` |
| Implementation checklist | `tasks.md` (internal, not on the public site) |

Published docs: [https://leanjunio.github.io/throw.it/](https://leanjunio.github.io/throw.it/)

---

## What the docs do well

Before the gaps, credit where it is due. These docs are above average for an early-stage product:

- **Clear product shape.** Two upload modes (signed-in vs anonymous), one playback path, listeners never need accounts. Easy to explain to a new teammate.
- **Happy-path flows are documented.** Upload → presigned PUT → confirm → share URL → playback is spelled out with sequence diagrams.
- **Listen counting is unusually precise.** The 0.5-second threshold, pass tracking, and replay-after-`ended` rules are the kind of detail that prevents endless "does this count as a listen?" debates.
- **`endpoint-handlers.md` is build-oriented.** Validation order, status codes, and handler steps read like an API contract.
- **Non-goals are explicit.** No transcoding, no public API, no CDN at MVP. That saves you from scope creep.

The gaps below are normal for docs at this stage. They are also exactly where junior-to-mid engineers get stuck if nobody resolves them first.

---

## How to read this review

Architects usually sort gaps into three buckets:

1. **Blockers** — You cannot implement correctly without a decision or a schema fix.
2. **Conflicts** — Two docs say different things; pick one before coding.
3. **Missing NFRs** — Security, cron schedules, observability. Often deferred at MVP, but you should know they are undefined.

Detail lives in sibling files under `architecture-gaps/`:

| File | Contents |
|------|----------|
| [01-implementation-blockers.md](architecture-gaps/01-implementation-blockers.md) | Schema holes and missing fields that break stated behavior |
| [02-doc-conflicts.md](architecture-gaps/02-doc-conflicts.md) | Where documents disagree |
| [03-open-questions.md](architecture-gaps/03-open-questions.md) | Decisions still needed, grouped by topic |
| [04-operational-gaps.md](architecture-gaps/04-operational-gaps.md) | Security, scaling, reliability, ops |

---

## Fix these before sprint planning

These are the highest-impact items. Everything else can wait; these will cause rework or bugs if ignored.

### 1. Filename is not stored anywhere

Confirm derives the track title from "the session's original filename" (`endpoint-handlers.md` §4.3). Initiation accepts `filename` in the request body but never persists it. `upload_sessions` has no `filename` column.

**Impact:** Anonymous uploads cannot get a title. Signed-in uploads lose the default title if the client does not resend it at confirm.

**Fix direction:** Add `original_filename` to `upload_sessions` at initiation.

### 2. Anonymous IP quota has no home in the schema

`architecture.md` says anonymous tracks capture IP for quota enforcement. The `tracks` ER diagram has no `ip_address`. `tasks.md` §6.2 says IP is stored on anonymous tracks, but §3.2 schema task does not include that column.

**Impact:** You cannot count "3 active tracks per IP" or "100 MB combined per IP" after confirm without either storing IP on `tracks` or documenting a join path that does not exist today.

**Fix direction:** Add `ip_address` to `tracks` (nullable, set only for anonymous), or document an alternative that actually works at query time.

### 3. Magic link reuse rules contradict each other

Three sources, three stories:

| Source | Rule |
|--------|------|
| `design.md` §5 | Reusable until **first successful sign-in** |
| `endpoint-handlers.md` §3.2 | After sign-in, link **may still work** on another device within 15 minutes |
| `uploader-auth` spec scenario | Same link works on phone and laptop within 15 minutes |

`magic_links.used_at` exists in the schema but no doc says when to set it.

**Impact:** Token invalidation logic is undefined. Email link prefetchers (common in corporate inboxes) make this worse.

**Fix direction:** Pick one rule, update all docs, define `used_at` behavior.

### 4. Anonymous per-file size limit is undefined

- `proposal.md` / `design.md`: 100 MB **combined** quota per IP
- `endpoint-handlers.md`: validates **≤ 500 MB** per file (same as signed-in), then rejects at quota check

A 200 MB file on an empty anonymous quota fails with **413** at step 5, not a clear "file too large for anonymous" message.

**Fix direction:** State an explicit anonymous per-file cap (probably ≤ 100 MB, or ≤ remaining quota).

### 5. Confirm idempotency wording contradicts itself

`endpoint-handlers.md` §4.3 step 2: already confirmed → **404**. Step 8 / idempotency note: retry after success → **200** with existing slug. The mermaid diagram shows the idempotent path correctly; step 2 text does not.

**Fix direction:** Step 2 should return 200 for already-confirmed sessions, 404 only for expired/missing.

### 6. Delete semantics: hard vs soft

`track-management` spec says "track record and stored audio file are removed." Architecture and handlers use soft delete (`deleted_at`) plus R2 delete plus slug retirement.

Behavior matches (404 on share URL), but the data model wording conflicts. Engineers may implement hard delete by mistake.

---

## Smaller gaps worth knowing about

These will not block an MVP, but you will hit them during implementation or testing:

- **Presigned URL TTL** is "1–4 hours" with no default (`design.md`, `tasks.md` §7.2).
- **Orphan sweeper delay** is "safe waiting period" with no number anywhere.
- **Cron schedule** for expire-tracks is "promptly" with no frequency.
- **Format warnings** (OGG on Safari) are in `design.md` and `audio-upload` spec but not in anonymous upload spec or handler docs (only rejection paths are documented).
- **UI prototypes** live at an absolute path on one machine (`design.md`). Not in repo; another developer cannot open them without separate access.
- **Library list API** is implied (Server Components) but never specified (sort, pagination, fields).
- **Client-trusted upload metadata** (`fileSizeBytes`, `contentType`) with no server-side HEAD size check on confirm.

---

## Doc hierarchy when sources conflict

The docs do not define precedence. Practical order until someone writes it down:

1. **Capability specs** (`specs/*/spec.md`) — testable behavior, good for acceptance criteria
2. **`endpoint-handlers.md`** — closest to implementation for API routes
3. **`design.md`** — product UX and architectural decisions
4. **`tasks.md`** — implementation checklist; sometimes drifts from specs (see magic link §4.7 vs handlers §3.2)

When specs and handlers disagree, stop and reconcile. Do not silently pick the handler doc because it is more detailed.

---

## Learning takeaway

Good architecture docs answer four questions for every important behavior:

1. **What happens in the happy path?** throw.it docs cover this well.
2. **What happens when things fail?** Partially covered; many error paths are open.
3. **What is stored where?** Strong intent, but schema and behavior drift (filename, IP).
4. **What are the numbers?** TTLs, cron intervals, rate limits, max string lengths — often missing or ranges without defaults.

As you write or review docs, chase question 3 and 4 early. That is where engineers otherwise guess, and guesses become production bugs.

---

## Next steps (suggested)

If you want to tighten the docs before building:

1. Resolve the six blockers above in a short ADR or design doc addendum.
2. Add missing columns to the ER diagram and `tasks.md` §3.2.
3. Pick numeric defaults (presigned TTL, sweeper delay, cron cadence) and put them in one "constants" section in `design.md`.
4. Either commit UI prototypes to the repo or publish them somewhere the team can reach.

See the detail files under `architecture-gaps/` for the full list of conflicts, open questions, and operational gaps.
