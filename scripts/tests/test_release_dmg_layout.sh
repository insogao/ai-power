#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/ai_power_dmg_layout_test.XXXXXX)"
APP_BUNDLE="$TMP_DIR/AI Power.app"
OUTPUT_DIR="$TMP_DIR/out"
MOUNT_POINT="$TMP_DIR/mount"

cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$OUTPUT_DIR"
touch "$APP_BUNDLE/Contents/MacOS/AI Power"
chmod +x "$APP_BUNDLE/Contents/MacOS/AI Power"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 9.9.9" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

APP_BUNDLE="$APP_BUNDLE" OUTPUT_DIR="$OUTPUT_DIR" "$ROOT_DIR/scripts/build_release_dmg.sh" >/dev/null

DMG_PATH="$OUTPUT_DIR/AI Power-9.9.9.dmg"
[[ -f "$DMG_PATH" ]]

mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -readonly -quiet

[[ -d "$MOUNT_POINT/AI Power.app" ]]
[[ -L "$MOUNT_POINT/Applications" ]]
[[ -f "$MOUNT_POINT/.DS_Store" ]]
