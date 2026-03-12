# Advanced Wake Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add advanced wake toggles, a concise built-in AI coverage summary, and compact active-tool badges without regressing the current AI continuity workflow.

**Architecture:** Keep the current slider-driven menu bar shell intact. Add a small persisted wake-options layer, thread it through policy resolution and menu UI, then add a presentation-only layer for built-in counts and active tool badges. Implement in three small increments so policy and UI risk stay isolated.

**Tech Stack:** Swift, SwiftUI, AppKit menu bar integration, IOKit power assertions, existing `AppModel` / `MonitoringEngine` / `SystemSupport` modules, Swift Testing.

---

### Task 1: Add the wake-options model

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add an `AppModelTests` case that expects default wake options to be:
  - computer sleep `true`
  - display dimming `false`
  - lock screen `false`

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_wake_options_red --filter AppModelTests`

Expected: the new test fails because `AppModel` does not expose wake options yet.

**Step 3: Write minimal implementation**

- Add a small wake-options value type.
- Expose it from `AppModel`.
- Seed it with the default values above.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_wake_options_green --filter AppModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift /Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add wake option defaults"
```

### Task 2: Add UI for the `Options` section

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add a test that toggles `Prevent Display Dimming` and `Prevent Lock Screen` through `AppModel`-level actions and verifies published state updates.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_options_ui_red --filter AppModelTests`

Expected: FAIL because toggle actions and state binding do not exist yet.

**Step 3: Write minimal implementation**

- Add `Options` disclosure UI in `MenuBarView`.
- Add toggle handlers in `AppModel`.
- Keep the section collapsed by default.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_options_ui_green --filter AppModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift /Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add advanced wake options section"
```

### Task 3: Thread wake options into power-assertion policy

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/ContinuityPolicyResolver.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerSystem/SystemSupport.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerCoreTests/ContinuityPolicyResolverTests.swift`

**Step 1: Write the failing test**

- Add resolver tests for:
  - default options => current behavior unchanged
  - display dimming option enabled => display-prevention assertion intent included
  - lock-screen option enabled but unsupported => degraded/explicit status

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_policy_red --filter ContinuityPolicyResolverTests`

Expected: FAIL because wake options are not part of policy resolution.

**Step 3: Write minimal implementation**

- Extend policy inputs to include wake options.
- Keep `prevent computer sleep` on existing path.
- Add display-sleep assertion intent as a conditional additive behavior.
- Model lock-screen prevention as best-effort with explicit degraded status if not fully supported.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_policy_green --filter ContinuityPolicyResolverTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerCore/ContinuityPolicyResolver.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerSystem/SystemSupport.swift /Users/gaoshizai/work/ai_power/Tests/AIPowerCoreTests/ContinuityPolicyResolverTests.swift
git commit -m "feat: wire wake options into continuity policy"
```

### Task 4: Add built-in AI coverage summary

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add an `AppModelTests` case asserting the summary text uses built-in keyword count only and excludes custom keywords.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_summary_red --filter AppModelTests`

Expected: FAIL because no dedicated built-in summary exists.

**Step 3: Write minimal implementation**

- Add a published/computed summary text such as `Monitoring 24 built-in AI tools`.
- Render it near the activity section or above `Monitors`.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_summary_green --filter AppModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift /Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add built-in ai coverage summary"
```

### Task 5: Add active tool badge model

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add a test that feeds active keywords and expects ordered badge items with `logo-first` then text fallback behavior.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_badges_red --filter AppModelTests`

Expected: FAIL because badge presentation model does not exist.

**Step 3: Write minimal implementation**

- Add a small active-badge presentation type.
- Build it from the recent activity window.
- Limit visible items and collapse overflow.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_badges_green --filter AppModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/AppModel.swift /Users/gaoshizai/work/ai_power/Sources/AIPowerCore/Models.swift /Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add active tool badge model"
```

### Task 6: Add bundled logo assets and badge UI

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Create: `/Users/gaoshizai/work/ai_power/Assets/` or the project’s existing asset location for bundled tool icons
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add a UI-model test verifying badge labels/order for tools with and without bundled logos.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_logo_ui_red --filter AppModelTests`

Expected: FAIL because the view still renders text-only activity.

**Step 3: Write minimal implementation**

- Bundle a small curated icon set for the highest-priority tools.
- Render compact logo badges in the panel.
- Fall back to text pills when no logo asset exists.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_logo_ui_green --filter AppModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift /Users/gaoshizai/work/ai_power/Assets /Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift
git commit -m "feat: add active tool logo badges"
```

### Task 7: Full verification

**Files:**
- Verify only

**Step 1: Run full test suite**

Run: `swift test --scratch-path /tmp/ai_power_advanced_controls_verify`

Expected: full suite passes.

**Step 2: Run signed build**

Run: `./scripts/build_signed_app.sh`

Expected: signed app produced at `/tmp/AIPowerSignedBuildLocal/Build/Products/Debug/AI Power.app`.

**Step 3: Manual smoke checks**

- Open app and verify `Options` appears.
- Toggle display dimming option and confirm UI status changes.
- Toggle lock-screen option and confirm any degraded/unsupported state is explained.
- Verify coverage summary text.
- Trigger `codex`, `kimi`, and `vscode` activity and inspect rendered badges.

**Step 4: Commit**

```bash
git add /Users/gaoshizai/work/ai_power
git commit -m "feat: add advanced wake controls and activity badges"
```
