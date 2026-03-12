# AI Power Manager Design

## Design Context

This repository started empty. The chosen MVP design optimizes for native macOS behavior, fast delivery, and strong testability. The user explicitly delegated design decisions, so this document fixes the implementation direction without a separate approval checkpoint.

## Design Summary

Build a menu bar app with three modes:

- `Auto` uses system activity signals plus hysteresis.
- `Developer` uses process detection.
- `Manual` always prevents sleep.

The UI stays intentionally small. Most complexity lives in a testable decision engine and a thin set of macOS adapters.

## Components

### Menu Bar UI

- Implemented with `MenuBarExtra`.
- Exposes mode selection, current reasons, current sleep action, and quit.
- No secondary window in MVP.

### App Model

- Single observable object consumed by the menu.
- Holds selected mode, status lines, and derived text for display.
- Receives periodic updates from the monitoring engine.

### Monitoring Engine

- Runs on a 1-second cadence.
- Pulls snapshots from CPU, network, disk, and process providers.
- Passes each snapshot to the decision engine.
- Reconciles desired sleep state through the assertion controller.

### Decision Engine

- Encodes business rules for all three modes.
- Keeps per-signal trackers so the engine knows whether a signal is merely spiking or truly active.
- Produces:
  - `reasons`
  - `shouldPreventSleep`
  - `sleepControlLabel`

### Signal Trackers

- One tracker each for CPU, network, and disk.
- Shared algorithm:
  - count time above enter threshold
  - activate after 10 consecutive seconds
  - remain active until value stays below exit threshold
- This avoids toggling around edge values.

### System Integrations

- CPU: delta between total and idle CPU ticks.
- Network: delta of interface byte counters from `getifaddrs`.
- Disk: sum read/write byte deltas from block storage statistics.
- Processes: inspect running applications plus known executable names.
- Sleep control: own a single `IOPMAssertion` and reuse it until state changes.

## Error Handling

- Missing sampler data does not crash the app.
- The engine treats unavailable data as inactive for that tick and can expose an informational reason like `Disk sampling unavailable`.
- Assertion errors update status text and are logged.

## UX Rules

- Default launch mode is `Auto`.
- Status text prefers the strongest active reason set:
  - manual override
  - developer process list
  - auto activity reasons
  - idle
- Sleep control text is binary:
  - `Preventing sleep`
  - `Allowing sleep`

## Testing Scope

- Hysteresis entry and exit thresholds
- 10-second dwell activation
- Mode precedence
- Developer mode process matching
- Manual mode override
- Engine to assertion-controller reconciliation
