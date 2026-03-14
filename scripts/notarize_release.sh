#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <artifact-path>" >&2
  echo "Artifact may be either an .app bundle or a .dmg file." >&2
  exit 1
fi

ARTIFACT_PATH="$1"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

if [[ ! -e "$ARTIFACT_PATH" ]]; then
  echo "Artifact not found: $ARTIFACT_PATH" >&2
  exit 1
fi

submit_with_profile() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

submit_with_apple_id() {
  xcrun notarytool submit "$1" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
}

if [[ -n "$NOTARY_PROFILE" ]]; then
  submit_artifact() {
    submit_with_profile "$1"
  }
elif [[ -n "$APPLE_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" && -n "$APPLE_TEAM_ID" ]]; then
  submit_artifact() {
    submit_with_apple_id "$1"
  }
else
  echo "Notarization credentials are not configured." >&2
  echo "Set NOTARY_PROFILE, or set APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID." >&2
  exit 1
fi

if [[ -d "$ARTIFACT_PATH" && "$ARTIFACT_PATH" == *.app ]]; then
  ZIP_PATH="${ARTIFACT_PATH%/}.zip"
  rm -f "$ZIP_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$ARTIFACT_PATH" "$ZIP_PATH"
  submit_artifact "$ZIP_PATH"
  xcrun stapler staple "$ARTIFACT_PATH"
  xcrun stapler validate "$ARTIFACT_PATH"
  spctl -a -vv "$ARTIFACT_PATH"
elif [[ -f "$ARTIFACT_PATH" && "$ARTIFACT_PATH" == *.dmg ]]; then
  submit_artifact "$ARTIFACT_PATH"
  xcrun stapler staple "$ARTIFACT_PATH"
  xcrun stapler validate "$ARTIFACT_PATH"
else
  echo "Unsupported artifact: $ARTIFACT_PATH" >&2
  echo "Expected a .app bundle or .dmg file." >&2
  exit 1
fi

echo
echo "Notarization completed:"
echo "  $ARTIFACT_PATH"
