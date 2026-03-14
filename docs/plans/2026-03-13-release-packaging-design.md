# AI Power Release Packaging Design

## Goal

Create a repeatable release pipeline for AI Power that produces:

- a signed `Release` app bundle;
- a distributable `.dmg`;
- a notarization path for both the app and the DMG; and
- a simple installation checklist for release verification.

## Constraints

- The project already has a working `Apple Development` signing path for local testing.
- Public release requires `Developer ID Application`.
- Notarization credentials may not exist yet on every machine, so the packaging flow must work before the notarization step.
- Release artifacts should not be committed to git.

## Recommended Flow

1. Build an unsigned `Release` bundle with `xcodebuild`.
2. Re-sign the embedded helper with `Developer ID Application`.
3. Sign the app bundle with `Developer ID Application`, hardened runtime, and timestamp.
4. Verify the app signature locally.
5. Create a plain drag-to-install DMG containing:
   - `AI Power.app`
   - `Applications` symlink
6. Notarize and staple the `.app`.
7. Create the DMG from the stapled app.
8. Notarize and staple the DMG.
9. Run an installation smoke test from the DMG.

## Scripts

- `scripts/build_release_app.sh`
  Builds and signs the release app bundle.
- `scripts/build_release_dmg.sh`
  Creates the DMG from a signed app bundle.
- `scripts/notarize_release.sh`
  Notarizes and staples either an app bundle or a DMG using `notarytool`.

## Artifact Layout

Artifacts should land in `dist/release/`:

- `AI Power.app`
- `AI Power-<version>.app.zip`
- `AI Power-<version>.dmg`

## Verification

- `codesign --verify --deep --strict`
- `spctl -a -vv`
- `xcrun stapler validate`
- manual open/install test from the DMG
