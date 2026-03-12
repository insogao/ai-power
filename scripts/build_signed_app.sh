#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/AIPowerSignedBuildLocal}"
IDENTITY="${APPLE_DEVELOPMENT_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -n 1)"
fi

if [[ -z "$IDENTITY" ]]; then
  echo "No Apple Development signing identity found." >&2
  echo "Set APPLE_DEVELOPMENT_IDENTITY explicitly, for example:" >&2
  echo '  APPLE_DEVELOPMENT_IDENTITY="Apple Development: your name (TEAMID)" ./scripts/build_signed_app.sh' >&2
  exit 1
fi

cd "$ROOT_DIR"

xcodebuild \
  -project "$ROOT_DIR/AIPower.xcodeproj" \
  -scheme AIPower \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug/AI Power.app"
HELPER_BINARY="$APP_BUNDLE/Contents/Helpers/AIPowerContinuityHelper"
APP_ENTITLEMENTS="$ROOT_DIR/Config/App/AIPowerApp.entitlements"
HELPER_ENTITLEMENTS="$ROOT_DIR/Config/Daemon/AIPowerContinuityHelper.entitlements"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Built app bundle not found at $APP_BUNDLE" >&2
  exit 1
fi

if [[ ! -f "$HELPER_BINARY" ]]; then
  echo "Embedded helper binary not found at $HELPER_BINARY" >&2
  exit 1
fi

codesign --force --sign "$IDENTITY" --entitlements "$HELPER_ENTITLEMENTS" "$HELPER_BINARY"
codesign --force --sign "$IDENTITY" --entitlements "$APP_ENTITLEMENTS" --deep "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo
echo "Signed app ready:"
echo "  $APP_BUNDLE"
