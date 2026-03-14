#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
APP_BUNDLE="${APP_BUNDLE:-$OUTPUT_DIR/AI Power.app}"
CACHED_DMGBUILD_DIR="${CACHED_DMGBUILD_DIR:-$HOME/Library/Caches/ai_power/dmgbuild}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Signed app bundle not found at $APP_BUNDLE" >&2
  echo "Run ./scripts/build_release_app.sh first." >&2
  exit 1
fi

VERSION="$(defaults read "$APP_BUNDLE/Contents/Info" CFBundleShortVersionString)"
DMG_PATH="$OUTPUT_DIR/AI Power-$VERSION.dmg"
SETTINGS_FILE="$(mktemp /tmp/ai_power_dmgbuild_settings.XXXXXX.py)"
VOLUME_NAME="AI Power"

cleanup() {
  rm -f "$SETTINGS_FILE"
}
trap cleanup EXIT

rm -f "$DMG_PATH"

mkdir -p "$CACHED_DMGBUILD_DIR"
if ! PYTHONPATH="$CACHED_DMGBUILD_DIR" python3 -c "import dmgbuild" >/dev/null 2>&1; then
  python3 -m pip install --quiet --target "$CACHED_DMGBUILD_DIR" dmgbuild==1.6.5
fi

cat >"$SETTINGS_FILE" <<EOF
application = "AI Power"
format = "UDZO"
files = [defines["app_bundle"]]
symlinks = {"Applications": "/Applications"}
background = None
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((100, 100), (700, 420))
arrange_by = None
grid_spacing = 100
label_pos = "bottom"
text_size = 14
icon_size = 128
icon_locations = {
    "AI Power.app": (160, 170),
    "Applications": (440, 170),
}
EOF

PYTHONPATH="$CACHED_DMGBUILD_DIR" python3 -m dmgbuild \
  -s "$SETTINGS_FILE" \
  -D "app_bundle=$APP_BUNDLE" \
  "$VOLUME_NAME" \
  "$DMG_PATH" >/dev/null

echo
echo "Release DMG ready:"
echo "  $DMG_PATH"
