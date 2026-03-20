# AI Power Release Workflow

## Prerequisites

- `Developer ID Application` installed in the login keychain
- Xcode command line tools available
- notarization credentials configured through either:
  - `xcrun notarytool store-credentials`, or
  - `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, and `APPLE_TEAM_ID`

## 1. Build the signed Release app

```bash
cd /Users/gaoshizai/work/ai_power
./scripts/build_release_app.sh
```

Output:

- `dist/release/AI Power.app`

## 2. Notarize and staple the app

If you already stored a keychain profile:

```bash
NOTARY_PROFILE="AI_POWER_NOTARY" ./scripts/notarize_release.sh "dist/release/AI Power.app"
```

Or use direct environment variables:

```bash
APPLE_ID="your-apple-id@example.com" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APPLE_TEAM_ID="RAXC5D3A3S" \
./scripts/notarize_release.sh "dist/release/AI Power.app"
```

## 3. Build the DMG

```bash
./scripts/build_release_dmg.sh
```

Output:

- `dist/release/AI Power-<version>.dmg`

Notes:

- The DMG is generated as a standard drag-to-Applications installer layout.
- The first run may bootstrap a small Python packaging dependency into `~/Library/Caches/ai_power/dmgbuild`.

## 4. Notarize and staple the DMG

```bash
NOTARY_PROFILE="AI Power" ./scripts/notarize_release.sh "dist/release/AI Power-0.1.3.dmg"
```

## 5. Installation smoke test

1. Double-click the DMG.
2. Drag `AI Power.app` into `Applications`.
3. Launch AI Power from `Applications`.
4. Confirm the menu bar icon appears.
5. Confirm the first-run permission flow appears when required.
6. Quit the app and relaunch once to confirm persistence.
