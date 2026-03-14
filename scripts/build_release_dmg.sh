#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
APP_BUNDLE="${APP_BUNDLE:-$OUTPUT_DIR/AI Power.app}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Signed app bundle not found at $APP_BUNDLE" >&2
  echo "Run ./scripts/build_release_app.sh first." >&2
  exit 1
fi

VERSION="$(defaults read "$APP_BUNDLE/Contents/Info" CFBundleShortVersionString)"
DMG_PATH="$OUTPUT_DIR/AI Power-$VERSION.dmg"
STAGING_DIR="$(mktemp -d /tmp/ai_power_dmg_stage.XXXXXX)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

rm -f "$DMG_PATH"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "AI Power" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Release DMG ready:"
echo "  $DMG_PATH"
