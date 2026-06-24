# Operational and non-functional gaps

The throw.it docs focus on product behavior and happy paths. That is normal for MVP specs. This file lists what is **not decided** for security, reliability, scaling, and day-two operations.

You do not need all of this on day one. You do need to know it is undefined so you do not assume someone else already decided it.

---

## Security

| Topic | Status in docs |
|-------|----------------|
| Session cookie attributes (`HttpOnly`, `Secure`, `SameSite`) | `HttpOnly` mentioned in `tasks.md`; rest missing |
| CSRF on cookie-authenticated mutations | Not mentioned |
| Rate limits: magic link, listen POST, upload initiation | Only anonymous quota limits defined |
| `X-Forwarded-For` trust model | "Use on Vercel" — parsing algorithm not specified |
| Presigned URL leakage (Referer, logs, browser history) | Not discussed |
| File content validation beyond extension/MIME | Magic bytes rejected for MVP in `design.md`; spoofed Content-Type risk remains |
| R2 bucket policy (private, no list, CORS whitelist) | CORS in local `tasks.md` §1.2; prod policy not documented |
| Account enumeration via magic link API | Returns 200 always (good); timing leaks not discussed |
| IP address storage and retention (privacy) | IPs used for quota; retention after TTL/delete not stated |

**Architect note:** Direct-to-R2 upload is the right pattern. Most MVP security work sits in cookie settings, CORS, and abuse limits on magic links and listen counts.

---

## Scaling and performance

| Topic | Status in docs |
|-------|----------------|
| Target concurrent users at launch | "Hundreds of uploaders" in `design.md` — no listener count |
| Vercel serverless limits (timeout, body size) | Not mentioned |
| Neon connection pooling / cold starts | Not mentioned |
| R2 free tier 10 GB vs platform-wide storage math | Not modeled |
| Library unbounded row count per uploader | No pagination |
| Max simultaneous presigned streams per track | No limit |

**Architect note:** At hundreds of uploaders, free tiers are plausible. The first pain point is often R2 storage cap and Neon sleep, not app code.

---

## Reliability and data integrity

| Topic | Status in docs |
|-------|----------------|
| Idempotency beyond upload confirm | Listen POST, delete retry not idempotent |
| DB + R2 two-phase operations | Delete: soft-delete → R2 delete → retire slug; no rollback if R2 fails |
| Backup / RPO / RTO for Postgres | Not mentioned |
| R2 lifecycle policies | Not mentioned |
| Cleanup job failure alerting | Not mentioned |
| Same-ticket confirm retry UX | Mentioned in `design.md` risks; not in handler error catalog |

**Architect note:** The delete flow is the classic dual-write problem. For MVP, document "if R2 delete fails, log and retry job" rather than leaving silent inconsistency.

---

## Observability

| Topic | Status in docs |
|-------|----------------|
| Structured logging (request id, slug, uploader id) | Not mentioned |
| Metrics: upload success, confirm failure, magic link delivery | Not mentioned |
| Alerting: R2/Neon/Resend failures | Not mentioned |
| Tracing across Next.js → Postgres → R2 | Not mentioned |
| SLOs (playback TTFB, upload completion time) | Not mentioned |

**Architect note:** At minimum, log cleanup job counts and email send failures. Those are the first things that break silently in production.

---

## Operations and deployment

| Topic | Status in docs |
|-------|----------------|
| Environment variable catalog | Partial in `tasks.md` §2.2 (`.env.example` task) |
| Preview vs production isolation | Not mentioned |
| Database migration strategy | Drizzle in `tasks.md`; rollback policy not stated |
| Resend domain verification, bounces | Named; bounce handling not specified |
| Local dev parity | Strong in `tasks.md` (Docker, MinIO, Mailpit) |
| Cron auth on Vercel (`CRON_SECRET`) | Not mentioned |

---

## Compliance and abuse

| Topic | Status in docs |
|-------|----------------|
| Content moderation | Explicit non-goal |
| DMCA / abuse reporting | Not mentioned |
| Listen count inflation | Accepted at MVP in `design.md` |
| Shared IP blocking for anonymous | Accepted; no escape hatch |
| GDPR: IP storage, email retention, account deletion | Not addressed |

---

## Accessibility and i18n

| Topic | Status in docs |
|-------|----------------|
| i18n | Out of scope; English hardcoded |
| a11y baseline | "MVP baseline" in `design.md` |
| WCAG target level | Not stated |
| Custom player screen reader behavior | Not specified |
| Keyboard shortcuts for player | Explicitly out for MVP |

---

## What "good enough for MVP" might look like

You do not need enterprise-grade everything on launch. A pragmatic minimum:

**Security**

- `Secure`, `HttpOnly`, `SameSite=Lax` session cookie
- R2 CORS locked to app origin
- Magic link rate limit: e.g. 5 requests / email / hour

**Reliability**

- Request-time expiry check on playback (do not rely on cron alone)
- Cleanup jobs log deleted counts; failed R2 deletes retried

**Observability**

- Structured logs on upload confirm failure and email send failure
- Cron job success/failure visible in Vercel logs

**Ops**

- `.env.example` with every required variable (already planned in `tasks.md`)
- Document cron schedule in `vercel.json` when chosen

Capture these as explicit decisions in `design.md` so they are not reinvented under pressure during implementation.

---

## Learning takeaway

Non-functional requirements feel boring until something breaks at 2 a.m. Architects list them early even when the answer is "defer." That way the team knows **conscious deferral** from **accidental omission**.

When you read any spec, ask: "What happens when this job fails, this URL leaks, or this table has ten million rows?" If the doc is silent, you have found a gap worth logging.
