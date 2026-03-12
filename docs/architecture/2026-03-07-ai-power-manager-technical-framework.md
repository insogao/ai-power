# AI Power Manager Technical Framework

## Stack

- Language: Swift 6
- UI: SwiftUI `MenuBarExtra`
- App lifecycle: SwiftUI app entry with accessory activation policy
- System APIs:
  - `IOPMAssertionCreateWithName` for sleep prevention
  - `host_statistics` / `host_processor_info` for CPU sampling
  - `getifaddrs` for network counters
  - IOKit block storage statistics for disk counters
  - `NSWorkspace` and process metadata for developer-process detection
- Build system: Swift Package Manager
- Testing: `swift-testing`

## Architectural Layers

### 1. App Layer

- Owns SwiftUI app entry and menu bar presentation.
- Binds UI to observable application state.
- Starts and stops monitoring on app lifecycle events.

### 2. Application Layer

- `AppModel` exposes mode, status lines, and sleep-control state.
- `MonitoringEngine` runs the 1-second tick and orchestrates samplers.
- `SleepAssertionController` creates/releases the macOS power assertion.

### 3. Domain Layer

- `DecisionEngine` evaluates sampled metrics and mode rules.
- `ActivitySignalTracker` applies dwell time and hysteresis for each metric.
- Domain models represent:
  - active mode
  - metric snapshots
  - active reasons
  - sleep action

### 4. Infrastructure Layer

- CPU sampler
- Network sampler
- Disk sampler
- Developer-process scanner
- Clock/timer abstraction for testing

## Module Layout

- `Sources/AIPowerApp/`
  - SwiftUI entry point
  - Menu UI
  - observable app model
- `Sources/AIPowerCore/`
  - domain models
  - decision engine
  - signal trackers
  - monitoring engine
  - protocol definitions
- `Sources/AIPowerSystem/`
  - macOS-specific samplers and sleep assertion implementation
- `Tests/AIPowerCoreTests/`
  - unit tests for core behavior

## Selected Approach

### Recommended

Use a pure Swift Package with a small app target and separate core/system targets.

Why this is the right MVP choice:

- fastest bootstrap from an empty repository
- testable core logic without UI dependencies
- no `.xcodeproj` maintenance burden
- easy to open directly in Xcode when needed

### Alternatives Considered

1. Single-target SwiftUI app.
   - simpler at first
   - worse testability and harder to isolate platform APIs

2. Split UI app plus background daemon/XPC service.
   - best long-term flexibility
   - too much operational complexity for MVP

3. AppKit-only status item app.
   - very mature for menu bar apps
   - slower to iterate than SwiftUI `MenuBarExtra`

## Data Flow

1. Timer ticks every second.
2. System samplers collect CPU, network, disk, and process snapshots.
3. `DecisionEngine` updates each signal tracker.
4. Engine resolves the effective reason set and target sleep action.
5. `SleepAssertionController` reconciles desired state with the live macOS assertion.
6. `AppModel` publishes mode, reasons, and current assertion state to the UI.

## Failure Strategy

- Sampler failure is non-fatal.
- If one sampler fails on a tick, keep the last known stable state for that metric and expose a degraded status message.
- If sleep assertion creation fails, surface the failure in UI state and logs.

## Testing Strategy

- Unit-test all decision logic in `AIPowerCore`.
- Use fake samplers and fake assertion controller for engine tests.
- Keep system integration thin and manually smoke test it on macOS.
