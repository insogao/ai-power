#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/AIPowerReleaseBuild}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
IDENTITY="${APPLE_DEVELOPER_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"
fi

if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application identity found." >&2
  echo "Install a Developer ID Application certificate, or set APPLE_DEVELOPER_IDENTITY explicitly." >&2
  exit 1
fi

cd "$ROOT_DIR"

xcodebuild \
  -project "$ROOT_DIR/AIPower.xcodeproj" \
  -scheme AIPower \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

SOURCE_APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Release/AI Power.app"
APP_BUNDLE="$OUTPUT_DIR/AI Power.app"
HELPER_BINARY="$APP_BUNDLE/Contents/MacOS/AIPowerContinuityHelper"
STALE_HELPER_BINARY="$APP_BUNDLE/Contents/Resources/AIPowerContinuityHelper"
APP_ENTITLEMENTS="$ROOT_DIR/Config/App/AIPowerApp.entitlements"
HELPER_ENTITLEMENTS="$ROOT_DIR/Config/Daemon/AIPowerContinuityHelper.entitlements"

if [[ ! -d "$SOURCE_APP_BUNDLE" ]]; then
  echo "Built app bundle not found at $SOURCE_APP_BUNDLE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_BUNDLE"
rsync -a "$SOURCE_APP_BUNDLE/" "$APP_BUNDLE/"
rm -f "$STALE_HELPER_BINARY"

if [[ ! -f "$HELPER_BINARY" ]]; then
  echo "Embedded helper binary not found at $HELPER_BINARY" >&2
  exit 1
fi

codesign --force --sign "$IDENTITY" --options runtime --timestamp --entitlements "$HELPER_ENTITLEMENTS" "$HELPER_BINARY"
codesign --force --sign "$IDENTITY" --options runtime --timestamp --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo
echo "Signed release app ready:"
echo "  $APP_BUNDLE"
