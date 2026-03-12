# Simplified Menu Slider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current engineering-oriented menu with a custom single-track interaction that exposes `AI Mode`, `Off`, and a smooth continuous `Keep Awake` time axis.

**Architecture:** Keep the existing monitoring engine and helper pipeline, but add a custom wake track model that maps drag positions to either snapped special zones (`AI Mode`, `Off`) or a continuous duration on the right-hand time axis. The UI becomes a compact custom control plus concise status text, while debug and helper details move to a secondary section.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, AppKit, existing AIPower core/system targets

---

### Task 1: Add simplified app control models

**Files:**
- Modify: `Sources/AIPowerApp/AppModel.swift`
- Modify: `Sources/AIPowerCore/Models.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- mapping custom-track selections to user-facing mode labels
- timed keep-awake selection hiding remaining information until the next panel open
- helper-ready AI mode clearing stale install guidance
- icon state collapsing to `idle`, `active`, or `warning`

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelTests`
Expected: FAIL because the simplified control model does not exist yet.

**Step 3: Write minimal implementation**

Add app-facing control types for:
- snapped `aiMode`
- snapped `off`
- continuous timed duration
- `infinity`

Update `AppModel` to:
- expose one selected control state
- derive primary and secondary status text
- derive remaining text visibility based on panel re-open
- surface icon state
- drive existing engine modes from the simplified selection

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerApp/AppModel.swift Sources/AIPowerCore/Models.swift Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add simplified wake control model"
```

### Task 2: Replace the menu with a slider-first UI

**Files:**
- Modify: `Sources/AIPowerApp/MenuBarView.swift`
- Modify: `Sources/AIPowerApp/AI_PowerApp.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add app-model tests that verify:
- `AI Mode` surfaces approval guidance when helper setup is blocked
- timed keep-awake hides countdown until the panel reopens
- icon presentation uses only idle, active, and warning
- timed selections map back to readable time labels

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelTests`
Expected: FAIL because the new derived presentation state is missing.

**Step 3: Write minimal implementation**

Update the menu to show:
- one custom drag track
- one primary status line
- one secondary action or guidance line
- one remaining capsule only on reopen
- optional debug disclosure

Update the menu bar extra symbol to reflect the new icon state.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerApp/MenuBarView.swift Sources/AIPowerApp/AI_PowerApp.swift Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: simplify menu bar controls"
```

### Task 3: Add timed keep-awake orchestration

**Files:**
- Modify: `Sources/AIPowerApp/AppModel.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- timed keep-awake forcing active sleep prevention
- timed keep-awake expiring back to `off`
- `infinity` staying active without expiration
- reopened panel showing minute-granularity remaining text

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelTests`
Expected: FAIL because manual timer orchestration does not exist.

**Step 3: Write minimal implementation**

Add a lightweight wake timer in the app model that:
- records an expiration date for timed presets
- drives the engine to the correct internal mode
- automatically returns to `off` after expiry

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerApp/AppModel.swift Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add timed keep-awake flow"
```

### Task 4: Final verification and manual test guide

**Files:**
- Modify: `docs/plans/2026-03-07-simplified-menu-slider-design.md`
- Modify: `docs/plans/2026-03-07-simplified-menu-slider-implementation.md`

**Step 1: Run the verification suite**

Run:
- `swift test`
- `swift build`
- `xcodebuild -project /Users/gaoshizai/work/ai_power/AIPower.xcodeproj -scheme AIPower -configuration Debug build`

Expected:
- all tests pass
- the signed app still builds

**Step 2: Verify the manual test flows**

Document and run:
- `Keep Awake` heartbeat test
- `AI Mode` heartbeat test with active workload
- `Off` recovery test

**Step 3: Commit**

```bash
git add docs/plans
git commit -m "docs: capture simplified slider test plan"
```
