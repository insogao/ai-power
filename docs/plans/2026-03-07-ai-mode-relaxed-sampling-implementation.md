# AI Mode Relaxed Sampling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `AI Mode` more tolerant of light AI workflows by combining relaxed activity sampling with keyword hits, while recording verbose debug logs for later analysis.

**Architecture:** Extend the current decision layer so per-second samples feed a slower exit policy and can also be activated by process keyword matches. Add a small app-facing keyword configuration surface and a debug logger that records raw sample inputs plus final decisions to disk.

**Tech Stack:** Swift 6, SwiftUI, Foundation, AppKit, Swift Testing, existing AIPower core/system/app targets

---

### Task 1: Add failing tests for relaxed AI sampling

**Files:**
- Modify: `Tests/AIPowerCoreTests/DecisionEngineTests.swift`
- Modify: `Tests/AIPowerAppTests/AppModelTests.swift`
- Test: `Tests/AIPowerCoreTests/DecisionEngineTests.swift`

**Step 1: Write the failing test**

Add tests for:
- keyword hits activating `AI Mode`
- `AI Mode` staying active during a quiet grace period
- `AI Mode` exiting only after five quiet minute windows

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_red --filter DecisionEngineTests`
Expected: FAIL because the current decision engine drops active state immediately once values fall below exit thresholds.

**Step 3: Write minimal implementation**

Update the decision logic to:
- accept keyword matches as an activation signal in `auto`
- maintain a slower inactivity countdown before returning to allowing sleep

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_green --filter DecisionEngineTests`
Expected: PASS

### Task 2: Add keyword configuration and visibility

**Files:**
- Modify: `Sources/AIPowerSystem/SystemSupport.swift`
- Modify: `Sources/AIPowerApp/AppModel.swift`
- Modify: `Sources/AIPowerApp/MenuBarView.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- built-in keywords surfacing in app state
- custom keywords merging with built-ins
- keyword-hit state surfacing in debug output

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_red --filter AppModelTests`
Expected: FAIL because keyword configuration is currently hard-coded and invisible to the UI.

**Step 3: Write minimal implementation**

Add:
- built-in keyword list expansion
- simple persisted custom keyword storage
- app-model/debug exposure for both lists
- lightweight add-keyword action in the panel

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_green --filter AppModelTests`
Expected: PASS

### Task 3: Add verbose debug logging

**Files:**
- Modify: `Sources/AIPowerCore/MonitoringEngine.swift`
- Modify: `Sources/AIPowerCore/Models.swift`
- Create: `Sources/AIPowerApp/DebugLogStore.swift`
- Test: `Tests/AIPowerCoreTests/MonitoringEngineTests.swift`

**Step 1: Write the failing test**

Add tests for:
- raw sample metrics being included in a debug log record
- keyword hits and final decisions being logged together

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_red --filter MonitoringEngineTests`
Expected: FAIL because no debug logging pipeline exists yet.

**Step 3: Write minimal implementation**

Add a simple append-only debug logger that records:
- timestamp
- mode
- CPU/network/disk
- keyword hits
- outcome reasons
- whether sleep prevention is active

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_relaxed_green --filter MonitoringEngineTests`
Expected: PASS

### Task 4: Verify and document the manual log-driven test flow

**Files:**
- Modify: `docs/plans/2026-03-07-ai-mode-relaxed-sampling-design.md`

**Step 1: Run verification**

Run:
- `swift test --scratch-path /tmp/ai_power_relaxed_full`
- `./scripts/build_signed_app.sh`

Expected:
- all relevant tests pass
- signed app builds successfully

**Step 2: Manual validation**

Use a real AI workflow session and compare approximate start/end times against the generated debug log.
