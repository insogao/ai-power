# Simplified Menu Slider Design

## Context

The current menu bar UI exposes internal implementation concepts such as `Mode`, `Continuity`, `Access`, and `Environment`. That structure matches the code architecture, but it does not match how a normal user decides whether the Mac should stay awake. The user feedback is explicit: the product should feel like one control with a small amount of supporting status, not a dashboard of toggles.

## Product Direction

The primary interaction becomes a single horizontal control with three logical zones:

- `AI Mode`
- `Off`
- `Keep Awake`

`Keep Awake` should not feel like a list of presets. The final control is a custom horizontal track:

- a small `AI Mode` region on the far left
- a small `Off` region just left of center
- a large continuous time axis across the right side
- a final `Infinity` cap at the far right

The control should read as one decision: how should the machine stay awake right now.

## User Model

Users should not have to understand helper installation, continuity policies, CPU thresholds, or power assertions to operate the app.

The product behavior is therefore reframed as:

- Left: let AI activity decide
- Center: do nothing
- Right: force wakefulness for a chosen duration

Advanced implementation details remain in the product, but they move out of the primary control path.

## Information Hierarchy

### Primary

- One custom drag control
- One short status line
- One secondary line only when the app needs user action
- One remaining-time capsule only when the panel is reopened during an active timed session

### Secondary

- Optional `Debug` section for development builds
- Helper approval/install guidance only when it blocks `AI Mode`
- Environment details only in debug or diagnostics

### Removed From Primary Surface

- Separate `Mode` section
- Separate `Continuity` section
- Separate `Access` section as a permanent block
- Separate `Sleep Control` section

## State Model

The UI should expose a smaller set of user-facing states:

- `Idle`
- `Keeping awake until <time>`
- `Keeping awake indefinitely`
- `Needs Approval`
- `Error`

Internally, the existing engine can continue to use `AppMode`, `ContinuityMode`, helper status, and execution policy. The app model should map those internals into one concise state summary.

## Icon Behavior

The menu bar icon must communicate activity without opening the menu.

- Idle: gray
- Active: strong accent
- Warning: base icon plus a small `!`

There is no separate `monitoring` icon state. If the app is not actively preventing sleep, it should look idle unless there is a blocking warning.

## Manual Keep Awake Mapping

The simplified UI introduces a user-facing wake preset model:

- `off`
- `aiMode`
- `timed(duration)`
- `infinity`

For MVP behavior:

- `aiMode` maps to existing `AppMode.auto` + `ContinuityMode.aiContinuity`
- `off` maps to `AppMode.auto` + no forced keep-awake override
- `timed` and `infinity` map to a manual override that keeps the machine awake regardless of activity

The first implementation does not need to persist countdowns across relaunch unless it is already easy to do so.

## Remaining Time Presentation

Timed `Keep Awake` should not show countdown information while the user is actively choosing a value or immediately after a new value is chosen.

- While dragging: hide remaining time
- Immediately after release: still hide remaining time
- On the next panel open: show a small capsule such as `2h 58m remaining`
- Refresh cadence: once per minute

No thin progress bar is needed.

## Approval And Helper Handling

Helper setup must be automatic when the user drags to `AI Mode`.

If approval is required:

- The slider stays on `AI Mode`
- The status line changes to `Needs Approval`
- A single action button appears:
  - `Open Approval Settings` or `Retry`

The user should never need to understand `Install AI Continuity Helper` as a primary concept.

## Test Plan

The product should ship with explicit human test cases that mirror the user journey:

1. Keep Awake test
   - Move the slider to `1h`
   - Start a heartbeat script that writes every 5 seconds
   - Close the lid for 3 minutes
   - Confirm timestamps remain continuous

2. AI Mode test
   - Move the slider to `AI Mode`
   - Run a CPU-heavy or network-heavy task
   - Wait 15 seconds for hysteresis
   - Close the lid for 3 minutes
   - Confirm timestamps remain continuous

3. Recovery test
   - Move the slider back to `Off`
   - Close the lid for 2 minutes
   - Confirm the workload pauses, proving default sleep behavior is restored

4. Control behavior test
   - Drag across the time axis
   - Confirm the handle moves smoothly
   - Confirm the `AI Mode` and `Off` zones still snap cleanly
   - Confirm time labels make the selected range understandable

## Implementation Notes

- Keep the existing core engine and helper pipeline
- Replace the menu composition and app model surface area
- Add a small manual keep-awake timer model to the app layer
- Keep debug details available during development, but hide them behind a dedicated section
