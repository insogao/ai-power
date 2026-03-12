# Menu Bar Waveform Design

**Goal:** Replace the menu bar's default lightning glyph with the app's waveform visual language while preserving the custom warning orbit-X state.

## Approved Direction

- Idle state uses a restrained waveform badge.
- Active state uses a brighter waveform badge.
- Warning state keeps the orange orbit-X badge.

## Constraints

- The menu bar badge must remain legible at 18px.
- The app icon's full circular composition is too detailed to reuse directly.
- The small badge should echo the app icon's waveform and palette, not duplicate it literally.

## Recommendation

Draw a simplified waveform glyph directly in the badge:

- Dark slate badge background for idle/active states to better match the app logo.
- Teal waveform for idle, brighter teal for active.
- Keep the existing rounded-square menu bar badge shape for consistency and readability.
