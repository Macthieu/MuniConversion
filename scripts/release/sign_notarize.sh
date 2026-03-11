#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/MuniConvert.app" >&2
  exit 1
fi

APP_DIR="$1"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_NAME="${APP_NAME:-MuniConvert}"
VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || echo dev)}"

: "${APPLE_CODESIGN_IDENTITY:?APPLE_CODESIGN_IDENTITY is required}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "[error] app bundle not found: $APP_DIR" >&2
  exit 1
fi

echo "[sign] codesigning app with identity: $APPLE_CODESIGN_IDENTITY"
codesign --force --deep --options runtime --timestamp --sign "$APPLE_CODESIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  ZIP_FOR_NOTARY="$OUTPUT_DIR/${APP_NAME}-${VERSION}-notary-upload.zip"
  rm -f "$ZIP_FOR_NOTARY"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_FOR_NOTARY"

  echo "[notary] submitting app for notarization"
  xcrun notarytool submit "$ZIP_FOR_NOTARY" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

  echo "[notary] stapling ticket"
  xcrun stapler staple "$APP_DIR"
else
  echo "[warn] Notarization skipped (APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID missing)."
fi

SIGNED_ZIP="$OUTPUT_DIR/${APP_NAME}-${VERSION}-macOS.zip"
rm -f "$SIGNED_ZIP"
ditto -c -k --keepParent "$APP_DIR" "$SIGNED_ZIP"

echo "[ok] signed distribution zip: $SIGNED_ZIP"
