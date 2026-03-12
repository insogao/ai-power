# App State Logo Design

## Context

`/Users/gaoshizai/work/ai_power/logo.html` currently behaves like a waveform preview toy:

- it exposes multiple waveform styles and manual color picking
- it exports three animation frames for the currently selected state
- it is not aligned to a production app-state icon workflow

The product need is narrower and more concrete: ship two circular state icons for the app, `Busy` and `Idle`, and replace the app's current bundle icon with the new approved direction.

## Goal

Turn the existing waveform instrument concept into a pair of polished circular app-state icons:

- `Busy`
- `Idle`

The icon should preserve the approved "waveform instrument" feel while reading as one consistent visual system.

## Chosen Direction

Use the same geometry for both states and distinguish them through energy level rather than structure changes.

That means:

- same circular instrument composition
- same centerline and waveform language
- same restrained instrument grid
- different amplitude, glow strength, and color temperature

This keeps the two states visually related and avoids looking like two separate brands.

## Visual Language

The icon lives entirely inside the circle. The square canvas outside the circle remains transparent.

Inside the circle:

- very light instrument grid
- subtle cross-axis guidance
- restrained outer ring
- one horizontal waveform across the center

The wave should remain the hero. The supporting grid should feel present but quiet.

## State Treatment

### Busy

- higher amplitude
- brighter electric aqua-green waveform
- stronger glow
- slightly clearer instrument ring

This should feel active and capable without becoming neon noise.

### Idle

- lower amplitude
- cooler silver-blue waveform
- softer glow
- slightly quieter supporting lines

This should read as calm and available, not disabled.

## Export Strategy

We will produce:

- one SVG and one PNG for `Busy`
- one SVG and one PNG for `Idle`
- a generated `AppIcon.appiconset` that uses the `Busy` icon as the default app bundle icon

Using `Busy` as the bundle icon is a deliberate default choice because it better represents the product's active, instrument-like identity in Finder and app launches.

## Implementation Approach

To make this repeatable, the waveform drawing logic should be extracted into reusable JavaScript shared by:

- the browser preview page
- a Node-based asset export script

This allows visual iteration in HTML while keeping deterministic asset generation in the repository.

## Success Criteria

The work is successful if:

1. `logo.html` previews polished `Busy` and `Idle` states rather than generic wave demos.
2. The project contains exported `Busy` and `Idle` assets in stable file paths.
3. The app bundle icon resolves to the new waveform logo after project regeneration.
4. The generation path is repeatable without manual browser clicking.
