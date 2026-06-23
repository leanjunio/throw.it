# throw.it product documentation

throw.it lets audio professionals upload a track and share a single link. Anyone with the link can stream it in the browser; listeners never need an account.

This site is the product specification for the music link sharing platform: scope, design decisions, technical architecture, and behavioral requirements.

## Reading order

Start with **why and what**, then **how it is built**, then **capability specs** for testable behavior.

### 1. Overview

| Document | What you'll find |
|----------|------------------|
| [Proposal](proposal.md) | Problem, product scope, capabilities list, and impact |
| [Design](design.md) | Goals, constraints, UX flows, and decision rationale |

### 2. Architecture

| Document | What you'll find |
|----------|------------------|
| [Architecture](architecture.md) | System context, data model, routes, and cross-cutting flows |
| [Endpoint handlers](endpoint-handlers.md) | Per-route handler steps, validation order, and error paths |

### 3. Capabilities

Each capability has a spec with requirements and scenarios. Read these when you need precise, testable behavior.

| Capability | Spec |
|------------|------|
| Anonymous upload | [specs/anonymous-upload/spec.md](specs/anonymous-upload/spec.md) |
| Audio upload | [specs/audio-upload/spec.md](specs/audio-upload/spec.md) |
| Shareable playback | [specs/shareable-playback/spec.md](specs/shareable-playback/spec.md) |
| Track management | [specs/track-management/spec.md](specs/track-management/spec.md) |
| Uploader auth | [specs/uploader-auth/spec.md](specs/uploader-auth/spec.md) |

## Quick context

- **Two upload modes:** signed-in uploaders get a persistent library; anonymous uploaders get temporary hosting (10-minute TTL).
- **Share URLs:** short slugs at `/t/{slug}`; same playback path for both modes.
- **Listeners:** no account required; stream in-browser with refresh-on-demand delivery.
- **MVP stack:** Next.js, PostgreSQL, S3-compatible object storage (R2 in production), magic link auth for uploaders.

For the full picture, begin with the [Proposal](proposal.md).
