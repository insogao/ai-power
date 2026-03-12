# Monitors Submenu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose monitored applications and ports in a dedicated `Monitors` submenu-style section in the menu bar UI.

**Architecture:** Keep configuration state in `AppModel`, move presentation and add actions into a new `Monitors` section in `MenuBarView`, and leave `Debug` as read-only diagnostics. Add view tests first, then implement the minimal UI and feedback behavior.

**Tech Stack:** SwiftUI, Swift Testing, existing `AppModel` observable state

---

### Task 1: Add failing UI/state tests

**Files:**
- Modify: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing tests**

- Assert monitored ports are surfaced alongside monitored apps.
- Assert add actions update those published lists.

**Step 2: Run tests to verify failure**

Run: `swift test --scratch-path /tmp/ai_power_monitors_ui --filter AppModelTests`

**Step 3: Implement minimal state support if needed**

- Only if tests reveal missing published state or refresh behavior.

**Step 4: Run tests to verify pass**

Run: `swift test --scratch-path /tmp/ai_power_monitors_ui --filter AppModelTests`

### Task 2: Add failing menu view tests

**Files:**
- Create or Modify: `Tests/AIPowerAppTests/MenuBarViewTests.swift`

**Step 1: Write the failing tests**

- Verify `Monitors` summary appears.
- Verify app and port sections render current lists.
- Verify `Debug` no longer includes add controls.

**Step 2: Run tests to verify failure**

Run: `swift test --scratch-path /tmp/ai_power_monitors_ui --filter MenuBarViewTests`

**Step 3: Implement minimal menu view changes**

- Add `Monitors` disclosure section.
- Move add controls out of `Debug`.
- Show inline feedback.

**Step 4: Run tests to verify pass**

Run: `swift test --scratch-path /tmp/ai_power_monitors_ui --filter MenuBarViewTests`

### Task 3: Verify full app regression

**Files:**
- Modify: `Sources/AIPowerApp/MenuBarView.swift`
- Modify: `Sources/AIPowerApp/AppModel.swift`
- Modify: `Tests/AIPowerAppTests/AppModelTests.swift`
- Modify: `Tests/AIPowerAppTests/MenuBarViewTests.swift`

**Step 1: Run focused tests**

Run:
- `swift test --scratch-path /tmp/ai_power_monitors_ui --filter AppModelTests`
- `swift test --scratch-path /tmp/ai_power_monitors_ui --filter MenuBarViewTests`

**Step 2: Run full suite**

Run: `swift test --scratch-path /tmp/ai_power_monitors_ui_full`

**Step 3: Run signed build**

Run: `./scripts/build_signed_app.sh`
