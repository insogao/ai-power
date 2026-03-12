# Monitored Network AI Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `AI Mode` prevent sleep only when monitored applications show meaningful rolling network activity or a configured listening port is present.

**Architecture:** Replace the current snapshot-level keyword activation with a monitored-application aggregation layer. The sampler will emit one aggregated sample per configured keyword, the decision engine will evaluate rolling network windows over those aggregates, and the UI/logging layers will consume the final reasons instead of noisy per-sample keyword hits.

**Tech Stack:** Swift, Swift Testing, macOS process/network sampling via `ps`, `nettop`, `lsof`

---

### Task 1: Lock the desired behavior with tests

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerCoreTests/DecisionEngineTests.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/DebugLogStoreTests.swift`

**Step 1: Write the failing tests**

- Add a test proving CPU-only monitored activity does not prevent sleep.
- Add a test proving a rolling network window over monitored samples does prevent sleep.
- Add a test proving raw debug logs include monitored application aggregates.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_monitored_red --filter 'DecisionEngineTests|DebugLogStoreTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: failure showing missing/incorrect monitored-network behavior or missing raw log fields.

**Step 3: Write minimal implementation**

- Extend core models for monitored application aggregates.
- Thread those aggregates through the monitoring engine and raw log store.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_monitored_green --filter 'DecisionEngineTests|DebugLogStoreTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 2: Switch AI Mode to aggregated monitored-network decisions

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/DecisionEngine.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerSystem/SystemSupport.swift`

**Step 1: Write the failing test**

- Add a focused test covering the monitored keyword aggregation path.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_monitored_sampler_red --filter 'DecisionEngineTests|LiveMonitoringSamplerTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: failure until the sampler and engine agree on the new aggregate format.

**Step 3: Write minimal implementation**

- Build one aggregate per configured keyword from CPU/network samples.
- Allow support aliases like `python` only when the parent keyword is detected.
- Use rolling monitored-network windows and configured ports as the only auto-mode triggers.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_monitored_sampler_green --filter 'DecisionEngineTests|LiveMonitoringSamplerTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 3: Keep UI and logs aligned with final reasons

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/DebugLogStore.swift`

**Step 1: Write the failing test**

- Add a test proving recent activity labels come from final reasons, not noisy detected keywords.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_monitored_ui_red --filter AppModelTests --package-path /Users/gaoshizai/work/ai_power`

Expected: failure if UI still reads transient keyword detections.

**Step 3: Write minimal implementation**

- Feed only final reason labels into recent activity badges.
- Persist monitored aggregates in the raw process log.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_monitored_ui_green --filter AppModelTests --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 4: Final verification

**Files:**
- Verify current working tree only

**Step 1: Run targeted verification**

Run: `swift test --scratch-path /tmp/ai_power_monitored_verify --filter 'DecisionEngineTests|AppModelTests|DebugLogStoreTests|LiveMonitoringSamplerTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: targeted tests pass.

**Step 2: Run signed build verification**

Run: `cd /Users/gaoshizai/work/ai_power && ./scripts/build_signed_app.sh`

Expected: signed debug app builds successfully.
