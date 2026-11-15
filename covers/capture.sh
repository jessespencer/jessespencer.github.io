#!/bin/sh
# Captures live projects into covers/shots/ (1440×900 at 2x, dark mode), then renders their covers.
# URLs and crops come from covers/covers.txt; rows with url "-" are staged by hand and skipped.
# Usage: covers/capture.sh [slug]  (no slug captures every project with a URL)
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
  # Dark mode both ways (UI flag and the prefers-color-scheme media query); the virtual-time
  # budget lets data load, fonts settle and entrance animations finish before the shot.
  "$chrome" --headless $CHROME_FLAGS --hide-scrollbars --window-size=1440,900 --force-device-scale-factor=2 \
    --force-dark-mode --blink-settings=preferredColorScheme=0 --virtual-time-budget=12000 \
    --screenshot="$tmp/$slug.png" "$url" 2>/dev/null
  [ -s "$tmp/$slug.png" ] || { echo "capture failed: $slug ($url)" >&2; exit 1; }
  to_jpeg "$tmp/$slug.png" "covers/shots/$slug.jpg" 90
  echo "covers/shots/$slug.jpg  <- $url"
  covers/render.sh "$slug"
done <<EOF
$(manifest "$1")
EOF

[ -n "$found" ] || { echo "No cover named '$1' in covers/covers.txt" >&2; exit 1; }
