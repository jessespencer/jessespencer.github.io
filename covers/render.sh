#!/bin/sh
# Renders covers from covers/shots/ through covers/template.html into images/ as 1600×840 JPEGs.
# Crops come from covers/covers.txt.
# Usage: covers/render.sh [slug]  (no slug renders them all)
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
  [ -f "covers/shots/$slug.jpg" ] || { echo "skip $slug: no covers/shots/$slug.jpg" >&2; continue; }
  "$chrome" --headless $CHROME_FLAGS --hide-scrollbars --window-size=800,420 --force-device-scale-factor=2 \
    --screenshot="$tmp/$slug.png" "file://$PWD/covers/template.html?shot=$slug&$crop" 2>/dev/null
  to_jpeg "$tmp/$slug.png" "images/$slug.jpg" 85
  echo "images/$slug.jpg"
done <<EOF
$(manifest "$1")
EOF

[ -n "$found" ] || { echo "No cover named '$1' in covers/covers.txt" >&2; exit 1; }
