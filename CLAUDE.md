# Jesse Destroys — Project Instructions

## Overview

Static single-page portfolio site. No framework, no build step — just `index.html` with inline `<style>` and `<script>`.

## Tech Stack

- HTML, CSS, vanilla JS (all in `index.html`)
- No package manager, no dependencies
- Hosted on GitHub Pages with custom domain (`jessespencer.dev`, formerly `jessedestroys.com`, which Cloudflare now 301s here path for path; Zero is a Cloudflare Worker at `zero.jessespencer.dev`). This repo is the user site (`jessespencer/jessespencer.github.io`), so every project repo's Pages site is served at `jessespencer.dev/<repo>/` — link projects there, not at `github.io`, and don't add a top-level folder named like a project repo. The one exception is `rainbow/`: the old address of the Bible apps, which now live in the `bible` repo. It holds only redirect pages (Atlas and `timeline/` for Lineage), so old links keep working
- `covers/` holds the cover manifest, capture and render scripts, template and source shots — excluded from the Pages build. `.github/workflows/covers.yml` refreshes covers from the live sites and opens a PR
- `_config.yml` only excludes repo docs and `covers/` from the Pages build — add any new top-level `.md` there, or Pages will publish it
- `AGENTS.md` is a symlink to this file (for Codex) — edit `CLAUDE.md`, never the link

## Architecture

Everything lives in `index.html`:
- **Styles**: Inline `<style>` block in `<head>` — responsive breakpoints at 1100px (2 columns) and 768px (1 column)
- **Layout**: CSS grid of cards (3 columns), max-width 1400px container
- **Script**: IIFE at the bottom of `<body>` handles the rotating tagline animation
- **Design**: Dark theme (#000 background, #f5f5f5 text, rgba white for muted elements)

## Key Patterns

- Case studies are `<article class="experiment">` blocks in `<main class="experiments">`
- Two embed types: image thumbnails (`.experiment-thumb > img`) and 16:9 iframe embeds (`.embed-wrap`)
- Rotating tagline uses class-based CSS fade transitions (`#rotating-text`, `.fade-out`)
- Social links use inline SVG icons in the header

## Code Style (Project-Specific)

- This is a zero-dependency static site — do not introduce build tools, frameworks, or package managers unless explicitly asked
- Keep all code in `index.html` (inline styles and scripts) unless the site grows significantly
- Use vanilla JS — no jQuery, no module imports
- Maintain the existing design language: dark background, subtle hover states, minimal borders using `rgba(255,255,255,0.1)`

## Adding Content

To add a new case study, duplicate an `<article class="experiment">` block and update:
1. `.experiment-year` — year label
2. `.experiment-title` — project name
3. `.experiment-desc` — one-line description
4. `.experiment-link` — optional external URL
5. Embed: either an image thumbnail or an iframe in `.embed-wrap`. Thumbnails are 1600×840 JPEG covers in `images/`, all rendered from `covers/template.html` so the set stays uniform — never drop in a raw screenshot or a site's `og:image`:
   - Add a line to `covers/covers.txt`: slug, live URL (a path or query can pick the best state) and crop (`zoom`, `x`, `y`, so the subject fills the card, especially on sparse pages)
   - Run `covers/capture.sh <slug>`: it shoots the URL at 1440×900, 2x, dark mode into `covers/shots/<slug>.jpg`, then renders `images/<slug>.jpg`. To adjust only the crop, edit the manifest and run `covers/render.sh <slug>`
   - Shots that need staging (a light-only page on a dark background, a specific in-game moment) get url `-`: capture them by hand into `covers/shots/`; the scripts and CI never re-shoot them

## Covers

Refreshing a cover after a project ships is `covers/capture.sh <slug>` locally, or the **Refresh covers** workflow (Actions → Run workflow, slug blank for all). The workflow opens a PR only when an image changed; merging it deploys. It needs "Allow GitHub Actions to create and approve pull requests" enabled in the repo's Actions settings.

A project can refresh its own cover on every deploy by adding this as the last step of its Pages workflow, with a `COVERS_DISPATCH_TOKEN` secret (a fine-grained token with Contents read/write on `jessespencer/jessespencer.github.io`). It skips quietly when the secret isn't set:

```yaml
      - name: Refresh cover on jessespencer.dev
        env:
          GH_TOKEN: ${{ secrets.COVERS_DISPATCH_TOKEN }}
        run: |
          [ -n "$GH_TOKEN" ] || exit 0
          gh api repos/jessespencer/jessespencer.github.io/dispatches \
            -f event_type=project-deployed -f 'client_payload[slug]=<slug>'
```

To add a new rotating tagline, append a string to the `phrases` array in the `<script>` block.
