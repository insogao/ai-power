# AI Network Threshold Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a configurable AI network threshold with preset values and a compact 1-hour monitored-network sparkline in the Options section.

**Architecture:** Extend `WakeControlOptions` so the threshold is persisted and propagated through `MonitoringEngine` into `DecisionEngine`. Track a rolling in-memory series in `AppModel` from monitored application samples and render it as a lightweight SwiftUI sparkline in `MenuBarView`.

**Tech Stack:** Swift, SwiftUI, Foundation, existing `MonitoringEngine` / `DecisionEngine` pipeline, XCTest

---

### Task 1: Persist the threshold setting

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerSystem/SystemSupport.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Add threshold to `WakeControlOptions`**

Add `aiNetworkThresholdKilobytes` with default `30`.

**Step 2: Persist it in `WakeControlConfiguration`**

Add a defaults key and wire read/write paths.

**Step 3: Add an AppModel setter**

Mirror the existing idle grace pattern.

**Step 4: Add/update tests**

Verify the setting updates the in-memory box and defaults behavior.

### Task 2: Wire the threshold into runtime decisions

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/DecisionEngine.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/MonitoringEngine.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerCoreTests/DecisionEngineTests.swift`

**Step 1: Make the threshold mutable**

Add a setter on `DecisionEngine`.

**Step 2: Update `MonitoringEngine`**

Apply the threshold whenever `wakeControlOptions` changes and during initialization.

**Step 3: Add/update tests**

Verify lower and higher thresholds produce different outcomes from the same samples.

### Task 3: Track 1-hour monitored-network history

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Add a small rolling sample model**

Store timestamped totals derived from `monitoredApplicationSamples`.

**Step 2: Trim to 1 hour**

Keep only recent data on each refresh.

**Step 3: Expose normalized sparkline values**

Provide a `[Double]` or similar view-ready series.

**Step 4: Add/update tests**

Verify appending and trimming behavior.

### Task 4: Render the option and sparkline

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MenuBarContentPresentationTests.swift`

**Step 1: Add `AI Network Threshold` picker**

Use preset menu choices: `10/30/50/80/100 KB`.

**Step 2: Add sparkline view**

Render a simple line/area chart with stable height and low visual weight.

**Step 3: Add caption text**

Explain that it shows monitored-network activity over the last hour.

### Task 5: Rebuild and verify manually

**Files:**
- Modify: none

**Step 1: Run targeted tests**

Run the updated DecisionEngine and AppModel tests.

**Step 2: Build signed app**

Use the documented signed build command.

**Step 3: Replace `/Applications/AI Power.app` and relaunch**

Verify the new threshold picker is visible and the sparkline updates while AI traffic is present.
