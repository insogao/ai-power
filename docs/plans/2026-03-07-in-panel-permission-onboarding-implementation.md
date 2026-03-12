# In-Panel Permission Onboarding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace external permission dialogs with a single in-panel onboarding flow that auto-opens once and guides the user through helper install and system approval.

**Architecture:** Keep helper installation and approval detection in `AppModel`, but replace `NSAlert` prompts with a derived permission card model that the SwiftUI popover renders directly. `MenuBarStatusController` listens for a one-shot onboarding-open signal and opens the popover automatically when setup is first needed.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, existing AIPower app/system/helper targets

---

### Task 1: Add failing model tests for in-panel onboarding

**Files:**
- Modify: `Tests/AIPowerAppTests/AppModelTests.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- pending helper setup exposes a permission card model instead of an alert prompt
- install completion advances the permission card to approval state
- repeated duration changes do not recreate onboarding actions

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_red --filter AppModelTests`
Expected: FAIL because the app model still depends on alert prompt callbacks.

**Step 3: Write minimal implementation**

Add app-model surface area for:
- permission card title
- permission card body
- permission card action title
- a one-shot auto-open request token

Remove alert-specific prompt plumbing from the new tests.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_green --filter AppModelTests`
Expected: PASS

### Task 2: Replace alert flow with in-panel actions

**Files:**
- Modify: `Sources/AIPowerApp/AppModel.swift`
- Modify: `Sources/AIPowerSystem/SystemSupport.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- startup onboarding requests an auto-open exactly once
- helper install transitions from install step to approval step without external prompt state
- manual retry remains available through the card action

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_red --filter AppModelTests`
Expected: FAIL because auto-open and card actions are not implemented yet.

**Step 3: Write minimal implementation**

Update `AppModel` to:
- derive a permission card directly from `HelperStatus`
- expose a monotonically changing onboarding-open trigger
- remove `NSAlert` request closures
- perform install and open-settings work directly from model actions

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_green --filter AppModelTests`
Expected: PASS

### Task 3: Render the card and auto-open the panel

**Files:**
- Modify: `Sources/AIPowerApp/MenuBarView.swift`
- Modify: `Sources/AIPowerApp/MenuBarStatusController.swift`
- Modify: `Sources/AIPowerApp/AI_PowerApp.swift`
- Test: `Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

Add tests for:
- permission card is absent when helper is ready
- permission card action titles match install vs approval
- auto-open trigger clears after first use

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_red --filter AppModelTests`
Expected: FAIL because the view/controller integration is missing.

**Step 3: Write minimal implementation**

Update the menu bar UI to:
- show a top permission card when the model exposes one
- remove the old standalone permission button wording
- auto-open the popover when the controller observes a fresh onboarding token

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_permission_panel_green --filter AppModelTests`
Expected: PASS

### Task 4: Verify and produce a single test path

**Files:**
- Modify: `scripts/fresh_permission_launch.sh` (only if needed)
- Modify: `docs/plans/2026-03-07-in-panel-permission-onboarding-design.md`

**Step 1: Run verification**

Run:
- `swift test --scratch-path /tmp/ai_power_permission_panel_full --filter AppModelTests`
- `./scripts/build_signed_app.sh`

Expected:
- all app-model tests pass
- signed app builds successfully

**Step 2: Manual verification**

Use one command:

```bash
cd /Users/gaoshizai/work/ai_power && ./scripts/fresh_permission_launch.sh
```

Expected:
- app launches
- popover auto-opens once if permission is needed
- permission card stays inside the panel
- no external `Not Now` dialog appears
