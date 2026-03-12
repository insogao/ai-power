#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="${DERIVED_DATA_PATH:-/tmp/AIPowerSignedBuildLocal}/Build/Products/Debug/AI Power.app"

echo "Closing existing AI Power processes..."
pkill -f "AI Power" || true

echo "Refreshing sudo session..."
sudo -v

echo "Resetting installed helper and permission state..."
"$ROOT_DIR/scripts/reset_closed_lid_access.sh"
sudo sfltool resetbtm || true

echo "Building signed app..."
"$ROOT_DIR/scripts/build_signed_app.sh"

echo "Launching app..."
open "$APP_BUNDLE"

echo
echo "AI Power launched from:"
echo "  $APP_BUNDLE"
echo
echo "The app should now show the permission guidance automatically on launch."
