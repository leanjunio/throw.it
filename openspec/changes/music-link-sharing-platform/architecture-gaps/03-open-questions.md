# Open questions

Decisions an architect would ask the product owner or tech lead to answer before implementation. Grouped so you can tackle one area at a time.

---

## Auth and sessions

1. After device A signs in with a magic link, can device B use the **same link** within 15 minutes? (See [02-doc-conflicts.md](02-doc-conflicts.md).)
2. What does `magic_links.used_at` do, and when is it set?
3. Session cookie: name, `Max-Age`, `Secure`, `SameSite`, path?
4. Is the 24-hour session **fixed from sign-in**, or **sliding** on activity?
5. Email normalization: is `User@x.com` the same as `user@x.com`?
6. Rate limit magic link requests per email or IP?
7. Corporate email **link prefetch**: if a scanner hits the verify URL first, does that consume the token?
8. User already signed in requests a new magic link anyway — send it, or redirect to library?
9. Sign out on device A while device B is uploading — allowed?

---

## Upload and storage

10. Anonymous **per-file max** size: 100 MB, 500 MB, or min(500, remaining quota)?
11. Verify R2 object size on confirm against declared `fileSizeBytes`?
12. MIME vs extension mismatch: reject if either fails, or require both to pass?
13. AAC: accept `.m4a`, `.aac`, both? Map to which MIME types?
14. Title max length, allowed characters, unicode?
15. Filename edge cases: empty stem (`.mp3`), path segments, very long names?
16. Presigned PUT: required `Content-Type` header? CORS config documented for prod R2?
17. Presigned GET TTL: pick 1 hour, 4 hours, or formula?
18. User refreshes mid-upload — is title/filename recovered from session or lost?
19. Confirm fails after successful R2 PUT — exact user-facing retry copy?
20. Upload session expires before confirm retry — user must re-upload entire file?

---

## Anonymous upload and IP quotas

21. Where is IP stored for quota on **confirmed** anonymous tracks?
22. `X-Forwarded-For`: use **first** IP in list (client) or **last** (trusted proxy)?
23. Shared IP (office, cafe): acceptable collateral blocking for MVP?
24. IPv6, missing IP in local dev — fallback behavior?
25. Do **in-progress** upload sessions count toward 100 MB IP quota before confirm?
26. Signed-in user on same IP starts anonymous upload while signed-in upload in progress — allow?

---

## Playback and listen counts

27. Expired anonymous URL opened in old tab — hard stop mid-play or finish buffer?
28. Autoplay policy — does first visit count without explicit play click?
29. Page **refresh** mid-play — new listen or same pass?
30. Seek near end of track — still counts if play started from &lt; 0.5s?
31. Bot/crawler or OG fetch hits share URL — increment listens?
32. Listen POST fails — optimistic UI rollback or silent ignore?
33. Listen POST returns 404 during race with delete — client behavior?
34. `duration_ms` null — show on UI? Block confirm?
35. Duration display format for &gt; 1 hour, unknown duration?
36. `og:image` — final asset path, dimensions, absolute production URL?

---

## Library and track management

37. Soft delete or hard delete for signed-in tracks? (Spec vs impl.)
38. Sort key for library: `created_at` desc confirmed?
39. Upload date display: timezone, locale, absolute vs relative?
40. Library pagination at MVP or unbounded table?
41. Share link column: show URL or copy-only (design says copy-only)?
42. Rename/delete while someone is listening — allowed?
43. Storage display: binary GB (GiB) or decimal GB?
44. Open playback page from library row, or copy-only?

---

## Background jobs and data lifecycle

45. Cron frequency for `expire-tracks` (every 1 min, 5 min, hourly)?
46. Orphan sweeper **waiting period** before deleting R2 objects (15 min, 1 h, 24 h)?
47. Request-time check: expired anonymous track 404 even if cleanup job has not run yet?
48. R2 delete fails after DB soft-delete — restore row or leave inconsistent?
49. Cleanup old `upload_sessions`, `magic_links`, `sessions` rows — ever, or grow forever?
50. `retired_slugs` grows forever — acceptable for MVP?

---

## Security and abuse (MVP scope)

51. CSRF protection for cookie-authenticated POST/PATCH/DELETE?
52. Rate limit listen increments per slug/IP, or accept inflation (`design.md` defers)?
53. Account deletion / GDPR — in or out of MVP?
54. DMCA/abuse contact — acknowledged non-goal; any takedown path?
55. Presigned URL leakage via Referer — concern or accepted?

---

## Platform and environments

56. Preview deployments: separate Neon/R2 or shared with prod?
57. Expected peak storage on R2 free tier — when to upgrade?
58. Vercel Hobby cron limits — three jobs at chosen frequency fit tier?
59. Neon cold start acceptable for first library load?

---

## Process and design assets

60. UI prototypes: commit to repo, publish link, or stay local-only?
61. Standard error message catalog for consistent UI states?
62. Which doc wins when capability spec contradicts `design.md`?

---

## Suggested resolution order

If you only have time for a short working session:

| Order | Questions | Why |
|-------|-----------|-----|
| 1 | 1, 2, 21 | Magic link + IP quota block core flows |
| 2 | 10, 11, 12 | Upload validation affects every upload path |
| 3 | 45, 46, 47 | Cleanup timing affects anonymous TTL correctness |
| 4 | 17, 36 | Playback and social previews |
| 5 | Rest | Polish, abuse, ops |

After answers land, update capability specs first, then `endpoint-handlers.md`, then `tasks.md` so the checklist matches.
