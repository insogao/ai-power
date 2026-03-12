# Warning Orbit Icon Design

**Goal:** Replace the current warning-state exclamation icon with a branded warning mark that matches the app's waveform/orbit visual language, and keep the signed-build flow unchanged.

## Context

The current warning state mixes system iconography with the new custom app logo language:

- The menu bar warning badge uses a plain `exclamationmark`.
- The permission card header still uses `bolt.shield.fill`.

This makes helper-install failures feel generic and visually disconnected from the rest of the app.

## Proposed Design

Use a compact orange warning mark built from two thin elliptical orbits crossing into an `X`.

- Keep the existing rounded-square warning badge container in the menu bar.
- Replace the internal warning glyph with a custom drawn orbit `X`.
- Replace the permission card header icon with the same orbit `X`.
- Keep existing copy, button behavior, and state logic unchanged.

## Constraints

- Must remain legible at very small menu bar sizes.
- Should feel branded, not like a generic system alert.
- Should not introduce a large new asset pipeline; code-drawn artwork is preferred.

## Recommendation

Implement the warning mark as shared code-generated artwork so both AppKit and SwiftUI can reuse the same geometry and colors without adding static image assets.
