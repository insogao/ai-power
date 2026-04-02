# AI Network Threshold Design

## Goal

Make AI Mode's network threshold user-configurable and give the user a lightweight 1-hour view of monitored-network activity so they can tune the threshold without guessing.

## Scope

- Add a persisted `AI Network Threshold` option with preset values.
- Add a compact 1-hour sparkline based on monitored application network samples.
- Keep the current 5-minute idle grace logic unchanged.
- Do not add a full analytics dashboard or per-app drilldown in this pass.

## Design

### Threshold configuration

The network threshold becomes part of `WakeControlOptions` so it behaves like the existing `AI Idle Grace` setting:

- Default: `30 KB / 60s`
- Presets: `10 KB`, `30 KB`, `50 KB`, `80 KB`, `100 KB`
- Persisted through the existing `WakeControlConfiguration` defaults path

This keeps the UI simple and avoids free-form values for now.

### Decision engine wiring

`DecisionEngine` already owns the `monitoredNetworkThresholdBytes` value. We will make it mutable so `MonitoringEngine` can update it whenever `wakeControlOptions` changes, just like it already does for idle grace.

### 1-hour sparkline

The sparkline will show the total monitored-network delta for each sampling point:

- Source: `snapshot.monitoredApplicationSamples`
- Value per tick: sum of `networkDeltaBytes` across monitored applications
- Retention: rolling 1 hour in memory
- Sampling interval: existing 2-second loop

This is intentionally session-local. We do not need to backfill from logs or persist chart history.

### UI

Inside `Options`:

- Add a new row: `AI Network Threshold`
- Add a menu picker with the preset values
- Add a compact sparkline below it
- Add one short caption explaining that the chart shows monitored-network activity from the last hour

## Non-goals

- No custom numeric input yet
- No histogram bins
- No per-app chart split
- No historical persistence across relaunches
