# AI Power Manager PRD

## 1. Product Summary

AI Power Manager is a macOS menu bar utility that decides when the system should stay awake during AI and developer workloads. The MVP targets solo developers who run local models, agent tools, downloads, builds, or long-running scripts and do not want the machine to sleep at the wrong time.

## 2. Problem Statement

macOS sleep interrupts AI inference, development tasks, downloads, and terminal work. Existing keep-awake tools are either fully manual or tied to specific applications. Users need a lightweight system-level tool that keeps the Mac awake when real work is happening and gets out of the way when the machine is idle.

## 3. Goals

- Prevent accidental sleep during real system activity.
- Provide a clear three-mode control model: `Auto`, `Developer`, `Manual`.
- Expose current decision reasons in a menu bar UI.
- Minimize false toggling through hysteresis and dwell time.
- Ship as a native macOS app with no external services.

## 4. Non-Goals

- Lid-close prevention in MVP.
- Fine-grained per-app rules.
- User-configurable thresholds in v1.
- Historical charts, notifications, onboarding, or settings windows.
- Cross-platform support.

## 5. Target Users

- AI developers running local inference, agent loops, or long API jobs.
- Software engineers running terminals, containers, builds, or scripts.
- Power users who want one-click keep-awake control.

## 6. User Stories

- As a user, I want the app to keep the Mac awake when CPU, network, or disk activity stays high long enough to indicate real work.
- As a developer, I want the app to stay awake when common dev tools are running, even if raw resource usage is low.
- As a user, I want to force a manual always-awake mode.
- As a user, I want to see why sleep is currently blocked.
- As a user, I want the app to stop blocking sleep once activity has truly subsided.

## 7. Functional Requirements

### 7.1 Modes

- `Auto Mode` is the default.
- `Developer Mode` blocks sleep when a known developer process is active.
- `Manual Mode` always blocks sleep until switched off.

### 7.2 Auto Mode Rules

- Sample every 1 second.
- CPU active when system CPU usage is above `30%` for at least `10` consecutive seconds.
- Network active when aggregate throughput is above `200 KB/s` for at least `10` consecutive seconds.
- Disk active when aggregate disk IO is above `1 MB/s` for at least `10` consecutive seconds.
- If any activity signal is active, prevent sleep.
- If all activity signals are inactive, allow sleep.
- Apply hysteresis:
  - CPU enter `30%`, exit `15%`
  - Network enter `200 KB/s`, exit `100 KB/s`
  - Disk enter `1 MB/s`, exit `512 KB/s`

### 7.3 Developer Mode Rules

- Detect common developer tools and shells:
  - `Terminal`
  - `iTerm`
  - `Cursor`
  - `Code / VS Code`
  - `Codex`
  - `Ollama`
  - `Docker`
  - `node`
  - `python`
  - `cargo`
  - `clang`
- If any configured developer process is active, prevent sleep.
- If no configured developer process is active, allow sleep.

### 7.4 Manual Mode Rules

- Always create and hold the sleep-prevention assertion.
- Show that the active reason is manual override.

### 7.5 UI Requirements

- Run as a menu bar app.
- Menu shows:
  - App title
  - Mode selector with current checkmark
  - Status section with active reasons
  - Sleep control section with current state
  - Quit action
- No dock icon in MVP.

## 8. Quality Requirements

- Decision loop latency: update within 1 second of a new sample.
- No rapid toggling around thresholds.
- App launches without additional setup.
- Core decision logic must be unit tested.

## 9. Success Criteria

- App builds and launches on a modern macOS development machine.
- Sleep assertion state correctly tracks the three modes.
- Unit tests cover mode transitions, hysteresis, and reason selection.
- Manual smoke testing confirms visible menu updates and sleep assertion changes.

## 10. Risks

- Disk IO APIs on macOS are lower level than CPU and process inspection.
- Sleep assertions require careful lifecycle management.
- Process detection by executable name can vary across distributions.

## 11. Post-MVP Roadmap

- Configurable thresholds and process lists.
- Launch at login.
- Event timeline and diagnostics.
- Lid-close AI mode research and hardware policy exploration.
