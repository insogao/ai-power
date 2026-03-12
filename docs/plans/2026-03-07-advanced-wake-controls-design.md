# Advanced Wake Controls Design

## Goal

Extend the menu bar experience with optional wake-related controls beyond the current default `Prevent Computer Sleep`, while keeping the primary AI workflow simple and uncluttered.

## Product Direction

- Keep the current slider-first interaction as the primary control surface.
- Treat advanced wake behavior as optional capability, not as part of the main mode-selection flow.
- Preserve the current default behavior:
  - `Prevent Computer Sleep` is on when AI Continuity or timed wake is active.
  - `Prevent Display Dimming / Sleep` is off by default.
  - `Prevent Lock Screen` is off by default.
- Expand the product’s built-in AI coverage so most users do not need to configure monitored tools manually.
- Surface active tools more visually by showing compact tool badges and, where available, logos.

## Why This Direction

- The current product already has a strong opinionated default: keep background AI work alive with minimum system intrusion.
- Adding more wake controls directly into the primary slider would make the panel harder to understand.
- Competing utilities such as Amphetamine expose multiple wake dimensions, but those are better treated as secondary controls in this product because the main job here is AI continuity, not generic power tweaking.

## External References

- Apple documents separate assertion types for system sleep and display sleep, which supports modeling these as distinct toggles rather than one combined switch:
  - `kIOPMAssertionTypePreventUserIdleSystemSleep`
  - `kIOPMAssertionTypePreventUserIdleDisplaySleep`
  - `kIOPMAssertionTypeNoDisplaySleep`
- VS Code’s extension-host architecture means many AI coding extensions do not show up as independent processes, so `VS Code alive` should remain the coverage boundary for extension-based tools.
- Amphetamine’s published feature/support docs suggest users understand separate concepts such as computer sleep, display sleep, and screen saver/lock behavior.

## Scope

This design covers three sequential product increments:

1. `Options` wake toggles
2. Built-in AI tool coverage summary
3. Active tool badges with logos

It does not cover:

- A separate Preferences window
- Per-extension introspection inside VS Code or Cursor
- Downloading remote logos at runtime
- Reworking the primary slider interaction

## Increment 1: Options Wake Toggles

### UX

- Add a collapsed `Options` disclosure section below the main activity/status area and above `Monitors`.
- Show three switches:
  - `Prevent Computer Sleep`
  - `Prevent Display Dimming`
  - `Prevent Lock Screen`
- `Prevent Computer Sleep` is enabled by default.
- The other two are disabled by default.
- Show a short note under the section when any non-default option is enabled, for example:
  - `Display dimming is currently blocked`
  - `Lock screen prevention is currently enabled`

### Behavior Model

- `Prevent Computer Sleep`
  - maps to current idle sleep prevention behavior
  - remains the only default-on option
- `Prevent Display Dimming`
  - adds a display-sleep assertion only while the app is actively keeping the machine awake
  - should never change user baseline permanently
- `Prevent Lock Screen`
  - is a best-effort capability
  - should be modeled separately from display sleep because lock behavior is influenced by system security settings and screen saver behavior
  - if the platform cannot reliably suppress the lock transition without side effects, the UI must clearly degrade instead of pretending success

### Technical Boundary

- System sleep and display sleep can be separated through public IOPM assertion types.
- Lock-screen prevention must be treated as a conditional capability rather than a guaranteed entitlement.
- No option may permanently rewrite the user’s baseline settings.

## Increment 2: Built-In AI Coverage Summary

### UX

- Add a concise summary line in the panel such as:
  - `Monitoring 24 built-in AI tools`
- Keep the full built-in list hidden by default.
- Continue allowing users to add custom app keywords and ports through `Monitors`.

### Behavior

- Built-in keywords are curated defaults, not exhaustive truth.
- VS Code-family extensions remain covered through `vscode / code helper`, rather than attempting to list every extension explicitly in detection UI.
- The summary count should reflect built-in tool entries only, not user-added items.

## Increment 3: Active Tool Badges and Logos

### UX

- Replace plain activity text like `Activity: codex, kimi` with compact visual badges.
- Badge order:
  1. tools with bundled logo assets
  2. tools without logo assets, rendered as text pills
- Cap visible badges to a small number such as 4, then collapse the remainder into `+N`.

### Logo Strategy

- Bundle a curated first-party asset set for major tools only.
- Do not fetch logos from the network at runtime.
- Tools without a bundled logo fall back to a text badge.

### Initial Logo Priority

- `Codex`
- `Claude`
- `Cursor`
- `VS Code`
- `Windsurf`
- `Gemini`
- `Kimi`
- `Qwen`

## Data Model Changes

- Add a persisted options model for wake controls, for example:
  - `preventComputerSleep: Bool`
  - `preventDisplaySleep: Bool`
  - `preventLockScreen: Bool`
- Add a lightweight presentation model for active tool badges:
  - tool id
  - display name
  - optional bundled asset name
  - last-seen timestamp

## Implementation Notes

- Default presets should be safe and minimal.
- Advanced options should only have effect while the wake policy is active.
- The UI must distinguish:
  - capability available and enabled
  - capability enabled but degraded
  - capability disabled by user

## Testing

- Unit tests for default wake options and their persistence.
- Unit tests for policy resolution when display prevention is enabled or disabled.
- Unit tests for badge ordering and fallback behavior.
- UI-model tests verifying that built-in coverage count is stable and excludes user-defined entries.

## Rollout Order

1. Wake options
2. Built-in AI count summary
3. Badge/logo presentation

## Notes

- This design intentionally avoids per-extension monitoring inside VS Code/Cursor because the architecture makes that expensive and brittle.
- The product’s differentiation remains:
  - strong AI defaults
  - low-friction continuity
  - clear user-facing status
