# Shared helpers for capture.sh and render.sh (sourced, not run).
# Works on macOS (Google Chrome + sips) and Linux CI (google-chrome + ImageMagick).
# CHROME overrides the browser path; CHROME_FLAGS adds flags (CI passes --no-sandbox).

find_chrome() {
  for c in "$CHROME" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    google-chrome google-chrome-stable chromium chromium-browser; do
    [ -n "$c" ] && command -v "$c" >/dev/null 2>&1 && { printf '%s\n' "$c"; return; }
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s\n' "$c"; return; }
  done
  echo "No Chrome found; set CHROME=/path/to/chrome" >&2
  exit 1
}

# to_jpeg <in.png> <out.jpg> <quality>
to_jpeg() {
  if command -v sips >/dev/null 2>&1; then
    sips -s format jpeg -s formatOptions "$3" "$1" --out "$2" >/dev/null
  elif command -v magick >/dev/null 2>&1; then
    magick "$1" -quality "$3" "$2"
  elif command -v convert >/dev/null 2>&1; then
    convert "$1" -quality "$3" "$2"
  else
    echo "Need sips (macOS) or ImageMagick to write JPEGs" >&2
    exit 1
  fi
}

# Manifest rows as "slug url crop", comments and blanks dropped; optional slug filter.
manifest() {
  grep -v '^[[:space:]]*#' covers/covers.txt | awk -v only="$1" 'NF >= 3 && (only == "" || $1 == only) { print $1, $2, $3 }'
}
