#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_NAME="${APP_NAME:-MuniConvert}"
BUNDLE_ID="${BUNDLE_ID:-com.municonvert.app}"
RAW_VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || echo dev)}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"

mkdir -p "$OUTPUT_DIR"

normalize_version_for_plist() {
  local raw="$1"
  local cleaned major minor patch

  cleaned="$(echo "$raw" | sed -E 's/^[vV]//; s/[^0-9.].*$//')"

  if [[ -z "$cleaned" ]]; then
    echo "0.0.0"
    return
  fi

  IFS='.' read -r major minor patch _ <<<"$cleaned"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"

  echo "${major}.${minor}.${patch}"
}

PLIST_VERSION="$(normalize_version_for_plist "$RAW_VERSION")"
DIST_VERSION="${RAW_VERSION:-$PLIST_VERSION}"
ICON_PNG="$ROOT_DIR/assets/AppIcon.png"
ICON_ICNS="$ROOT_DIR/assets/AppIcon.icns"
ICON_SCRIPT="$ROOT_DIR/scripts/release/generate_icns.sh"

echo "[build] swift build -c release --product $APP_NAME"
swift build -c release --product "$APP_NAME"

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "[error] binary not found: $BIN_PATH" >&2
  exit 1
fi

APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$PLIST_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$PLIST_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -f "$ICON_PNG" ]]; then
  echo "[icon] generating AppIcon.icns from AppIcon.png"
  bash "$ICON_SCRIPT" "$ICON_PNG" "$ICON_ICNS"
fi

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" || true
fi

# SwiftPM localized resources are emitted as *.bundle next to the binary.
while IFS= read -r -d '' bundle_dir; do
  bundle_name="$(basename "$bundle_dir")"
  echo "[resources] embedding SwiftPM bundle: $bundle_name"
  cp -R "$bundle_dir" "$APP_DIR/Contents/Resources/$bundle_name"
done < <(find "$BIN_DIR" -maxdepth 1 -type d -name "*.bundle" -print0)

echo "[sign] applying ad-hoc signature to app bundle"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

UNSIGNED_ZIP="$OUTPUT_DIR/${APP_NAME}-${DIST_VERSION}-unsigned.zip"
rm -f "$UNSIGNED_ZIP"
ditto -c -k --keepParent "$APP_DIR" "$UNSIGNED_ZIP"

echo "[ok] app bundle: $APP_DIR"
echo "[ok] plist version: $PLIST_VERSION"
echo "[ok] unsigned zip: $UNSIGNED_ZIP"
