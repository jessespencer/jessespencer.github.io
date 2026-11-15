#!/bin/sh
# Captures live projects into covers/shots/ (1440×900 at 2x, dark mode), then renders their covers.
# URLs and crops come from covers/covers.txt; rows with url "-" are staged by hand and skipped.
# Usage: covers/capture.sh [slug]  (no slug captures every project with a URL)
# Needs Node 22+ (covers/shoot.mjs). COVER_WAIT_MS sets the wait after page load (default 8000).
set -e
cd "$(dirname "$0")/.."
. covers/lib.sh

chrome=$(find_chrome)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

found=
while read -r slug url crop; do
  [ -n "$slug" ] || continue  # an empty manifest match still yields one blank line
  found=1
  if [ "$url" = "-" ]; then
    # Staged by hand: never re-shot. Named explicitly, it is re-cropped; in a full run it is
    # left untouched, so CI doesn't re-encode covers it has no new shot for.
    if [ -n "$1" ]; then
      echo "$slug is staged by hand (url '-' in covers/covers.txt); re-cropping only" >&2
      covers/render.sh "$slug"
    fi
    continue
  fi
  # Real-time wait (COVER_WAIT_MS after load, default 8s) so data loads, fonts settle and
  # entrance animations finish, including requestAnimationFrame ones. See covers/shoot.mjs.
  node covers/shoot.mjs "$chrome" "$url" "$tmp/$slug.jpg" </dev/null || true
  [ -s "$tmp/$slug.jpg" ] || { echo "capture failed: $slug ($url)" >&2; exit 1; }
  to_jpeg "$tmp/$slug.jpg" "covers/shots/$slug.jpg" 90
  echo "covers/shots/$slug.jpg  <- $url"
  covers/render.sh "$slug"
done <<EOF
$(manifest "$1")
EOF

[ -n "$found" ] || { echo "No cover named '$1' in covers/covers.txt" >&2; exit 1; }
