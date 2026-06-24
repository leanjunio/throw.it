# Agent guide: docs publishing

Instructions for agents editing OpenSpec markdown that appears on the public site.

## 1. Publishing model

- **Source:** `openspec/changes/music-link-sharing-platform/` — all published pages live here.
- **Config:** `mkdocs.yml` controls which files appear on the site and how they are organized in the nav.
- **Deploy:** Automatic on push to `main` via GitHub Actions. No workflow edits needed for content changes.

Published site: [https://leanjunio.github.io/throw.it/](https://leanjunio.github.io/throw.it/)

## 2. After editing OpenSpec docs

```
Did you add or rename a .md file that should appear on the public site?
├── NO  → push to main (or include in PR). Done.
└── YES → also update mkdocs.yml nav, then verify with make docs-build
```

Editing an existing published page does not require nav changes. Pushing to `main` triggers a redeploy.

## 3. How to update nav

Add a new entry under the appropriate section in `mkdocs.yml`. Paths are relative to `docs_dir` (`openspec/changes/music-link-sharing-platform/`).

Example: adding `specs/billing/spec.md` under Capabilities:

```yaml
- Capabilities:
    - Anonymous upload: specs/anonymous-upload/spec.md
    - Audio upload: specs/audio-upload/spec.md
    - Billing: specs/billing/spec.md
    - Shareable playback: specs/shareable-playback/spec.md
    - Track management: specs/track-management/spec.md
    - Uploader auth: specs/uploader-auth/spec.md
```

Current nav sections:

| Section | Pages |
|---------|-------|
| Home | `index.md` |
| Overview | `proposal.md`, `design.md` |
| Architecture | `architecture.md`, `endpoint-handlers.md` |
| Architecture gaps | `architecture-gaps/*.md` (five pages) |
| Capabilities | `specs/*/spec.md` (five capability specs) |

## 4. Files that are NOT published

These files exist in the change folder but are intentionally omitted from `mkdocs.yml` nav:

- `tasks.md` — implementation checklist; internal to the change, not visitor-facing docs.

If you add a new markdown file that should stay internal, do not add it to `nav`.

## 5. Local verification

First time only:

```bash
make docs-setup   # creates .venv and installs mkdocs-material
```

After any `mkdocs.yml` nav change or new published page:

```bash
make docs-build   # must succeed before claiming docs are ready
```

Optional preview:

```bash
make docs-serve   # http://127.0.0.1:8000 — spot-check mermaid on Architecture pages
```

`make docs-build` must exit 0 before you mark docs work complete.

## 6. Archive migration

When specs move from `openspec/changes/<change>/` to `openspec/specs/<capability>/spec.md` after an OpenSpec archive, update these fields in `mkdocs.yml`:

- `docs_dir`
- `nav` (all paths)
- `edit_uri`

Then run `make docs-build` to verify.
