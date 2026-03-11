#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 /path/to/AppIcon.png /path/to/AppIcon.icns" >&2
  exit 1
fi

SOURCE_PNG="$1"
OUTPUT_ICNS="$2"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "[error] source image not found: $SOURCE_PNG" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/AppIcon.iconset"
SQUARE_PNG="$WORK_DIR/AppIcon-square.png"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

read -r WIDTH HEIGHT < <(
  sips -g pixelWidth -g pixelHeight "$SOURCE_PNG" 2>/dev/null \
    | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}'
)

if [[ -z "${WIDTH:-}" || -z "${HEIGHT:-}" ]]; then
  echo "[error] unable to read source image dimensions with sips" >&2
  exit 1
fi

SIDE="$WIDTH"
if [[ "$HEIGHT" -lt "$WIDTH" ]]; then
  SIDE="$HEIGHT"
fi

# Keep aspect ratio by center-cropping to square before iconset export.
sips -c "$SIDE" "$SIDE" "$SOURCE_PNG" --out "$SQUARE_PNG" >/dev/null

write_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$SQUARE_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

write_icon 16 icon_16x16.png
write_icon 32 icon_16x16@2x.png
write_icon 32 icon_32x32.png
write_icon 64 icon_32x32@2x.png
write_icon 128 icon_128x128.png
write_icon 256 icon_128x128@2x.png
write_icon 256 icon_256x256.png
write_icon 512 icon_256x256@2x.png
write_icon 512 icon_512x512.png
write_icon 1024 icon_512x512@2x.png

mkdir -p "$(dirname "$OUTPUT_ICNS")"
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "[ok] generated icns: $OUTPUT_ICNS"
