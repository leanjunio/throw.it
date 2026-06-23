# throw.it

Upload audio and share a single link that opens a playable page in the browser.

## Documentation

Published docs: [https://leanjunio.github.io/throw.it/](https://leanjunio.github.io/throw.it/)

Docs are built from `openspec/` via [MkDocs](https://www.mkdocs.org/) and deployed to GitHub Pages on push to `main`.

### When docs change

| Change | Action needed |
|--------|---------------|
| Edit existing published page | Push to `main` — auto-deploys |
| Add a new page to the public site | Add file under `openspec/...`, then add entry to `nav` in [`mkdocs.yml`](mkdocs.yml) |
| Preview locally | `make docs-serve` (first time: `make docs-setup`) |

### Local commands

```bash
make docs-setup   # one-time: create .venv and install deps
make docs-serve   # preview at http://127.0.0.1:8000
make docs-build   # build site/ (gitignored)
```

Agents and detailed steps → see [AGENTS.md](AGENTS.md).
