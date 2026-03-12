# AI Power Manager Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an MVP macOS menu bar app that prevents sleep in `Auto`, `Developer`, and `Manual` modes using native system sampling and a tested decision engine.

**Architecture:** The app will use a Swift Package structure with three targets: a SwiftUI menu bar app target, a pure core logic target, and a macOS system adapter target. Decision logic remains test-first and platform-agnostic; only sampling and assertion control touch system APIs.

**Tech Stack:** Swift 6, SwiftUI `MenuBarExtra`, Swift Testing, IOKit, Foundation, AppKit

---

### Task 1: Bootstrap the package and app shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/AIPowerApp/AI_PowerApp.swift`
- Create: `Sources/AIPowerApp/MenuBarView.swift`
- Create: `Sources/AIPowerApp/AppModel.swift`

**Step 1: Write the failing test**

Write a tiny smoke test that imports `AIPowerCore` and expects the default mode to be `auto`.

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because the package and target do not exist yet.

**Step 3: Write minimal implementation**

Create the package, core target placeholder, and a SwiftUI menu bar app shell that can show the current mode.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS for the default-mode smoke test.

**Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: bootstrap AI Power app shell"
```

### Task 2: Add core domain models and signal tracking

**Files:**
- Create: `Sources/AIPowerCore/Models.swift`
- Create: `Sources/AIPowerCore/SignalTracker.swift`
- Test: `Tests/AIPowerCoreTests/SignalTrackerTests.swift`

**Step 1: Write the failing test**

Add tests for:
- activation only after 10 samples above threshold
- staying active until value falls below exit threshold

**Step 2: Run test to verify it fails**

Run: `swift test --filter SignalTrackerTests`
Expected: FAIL because tracker types do not exist.

**Step 3: Write minimal implementation**

Create activity models and a tracker that supports enter threshold, exit threshold, dwell seconds, and current active state.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SignalTrackerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerCore Tests/AIPowerCoreTests
git commit -m "feat: add hysteresis signal tracking"
```

### Task 3: Add decision engine rules

**Files:**
- Create: `Sources/AIPowerCore/DecisionEngine.swift`
- Test: `Tests/AIPowerCoreTests/DecisionEngineTests.swift`

**Step 1: Write the failing test**

Add tests for:
- manual mode always prevents sleep
- developer mode depends on detected process
- auto mode prevents sleep when any tracked signal becomes active
- auto mode allows sleep when all signals are inactive

**Step 2: Run test to verify it fails**

Run: `swift test --filter DecisionEngineTests`
Expected: FAIL because the engine is missing.

**Step 3: Write minimal implementation**

Create the engine with explicit rule ordering and reason generation.

**Step 4: Run test to verify it passes**

Run: `swift test --filter DecisionEngineTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerCore Tests/AIPowerCoreTests
git commit -m "feat: implement mode decision engine"
```

### Task 4: Add monitoring orchestration

**Files:**
- Create: `Sources/AIPowerCore/MonitoringEngine.swift`
- Test: `Tests/AIPowerCoreTests/MonitoringEngineTests.swift`

**Step 1: Write the failing test**

Add tests proving the engine:
- samples providers
- updates published state
- calls the assertion controller only when desired state changes

**Step 2: Run test to verify it fails**

Run: `swift test --filter MonitoringEngineTests`
Expected: FAIL because orchestration types do not exist.

**Step 3: Write minimal implementation**

Create provider protocols, engine state, and assertion reconciliation logic.

**Step 4: Run test to verify it passes**

Run: `swift test --filter MonitoringEngineTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerCore Tests/AIPowerCoreTests
git commit -m "feat: add monitoring orchestration"
```

### Task 5: Add macOS system adapters

**Files:**
- Create: `Sources/AIPowerSystem/SystemSamplers.swift`
- Create: `Sources/AIPowerSystem/SleepAssertionController.swift`
- Modify: `Package.swift`
- Test: `Tests/AIPowerCoreTests/DecisionEngineTests.swift`

**Step 1: Write the failing test**

Add at least one integration-shape test around process name normalization or assertion reconciliation assumptions if needed in core.

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL for the new behavior.

**Step 3: Write minimal implementation**

Implement live samplers for CPU, network, disk, and processes plus the real assertion controller.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: add macOS system integrations"
```

### Task 6: Bind UI to live engine state

**Files:**
- Modify: `Sources/AIPowerApp/AI_PowerApp.swift`
- Modify: `Sources/AIPowerApp/MenuBarView.swift`
- Modify: `Sources/AIPowerApp/AppModel.swift`

**Step 1: Write the failing test**

Add a small app-model test for mode changes updating derived labels.

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because bindings or derived labels are incomplete.

**Step 3: Write minimal implementation**

Wire the live engine into the app model and render mode, reasons, and sleep-control state in the menu.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: connect menu UI to monitoring engine"
```

### Task 7: Final verification

**Files:**
- Review: `docs/product/2026-03-07-ai-power-manager-prd.md`
- Review: `docs/architecture/2026-03-07-ai-power-manager-technical-framework.md`
- Review: `docs/plans/2026-03-07-ai-power-manager-design.md`

**Step 1: Run the full verification suite**

Run:
- `swift test`
- `swift build`

Expected:
- all tests pass
- app target builds successfully

**Step 2: Manual smoke check**

Run the app from Xcode or `swift run AIPowerApp` and confirm:
- menu bar extra appears
- mode switching updates labels
- assertion state changes

**Step 3: Commit**

```bash
git add .
git commit -m "feat: deliver AI Power Manager MVP"
```
