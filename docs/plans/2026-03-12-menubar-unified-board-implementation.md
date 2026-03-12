# Menu Bar Unified Board Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the menu bar icon use one shared background board while increasing waveform and warning glyph size for better readability at 18px.

**Architecture:** Keep the existing AppKit-drawn menu bar image pipeline. Update `MenuBarIconDescriptor` so all states share one board style, then enlarge the glyph rects and reduce internal padding in `WaveformBadgeArtwork` and `WarningOrbitArtwork`. Add tests that lock the shared-board choice and the minimum glyph footprint.

**Tech Stack:** Swift, AppKit, Swift Testing, Xcode build

---

### Task 1: Lock the shared board and enlarged glyph geometry

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MenuBarIconDescriptorTests.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarStatusController.swift`

**Step 1: Write the failing test**

Add expectations that all menu bar states map to the same badge style and that the warning glyph rect is substantially larger than before.

**Step 2: Run test to verify it fails**

Run: `swift test --filter MenuBarIconDescriptorTests`
Expected: FAIL because the descriptor still uses different badge styles and the current geometry helpers are too small.

**Step 3: Write minimal implementation**

Add or update the shared board style and expose geometry helpers used by the tests.

**Step 4: Run test to verify it passes**

Run: `swift test --filter MenuBarIconDescriptorTests`
Expected: PASS unless blocked by the existing local `.xctest` signing policy issue, in which case compilation should succeed and the runtime policy failure should be reported.

### Task 2: Enlarge the waveform and warning artwork

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarStatusController.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/WaveformBadgeArtwork.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/WarningOrbitArtwork.swift`

**Step 1: Update badge and glyph placement**

Increase the background board footprint slightly and expand the waveform / warning glyph rects.

**Step 2: Reduce internal padding in the drawing code**

Let the waveform and orbit-X use more of their provided rects.

**Step 3: Verify with a project build**

Run: `xcodebuild -project /Users/gaoshizai/work/ai_power/AIPower.xcodeproj -scheme AIPower -configuration Debug -derivedDataPath /tmp/AIPowerDerivedUnifiedBoard CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`

### Task 3: Deliver a runnable app bundle

**Files:**
- Output: `/Users/gaoshizai/work/ai_power/dist/AI Power Unsigned <timestamp>.app`

**Step 1: Copy the built app to a stable path**

Copy the latest app bundle from `/tmp/AIPowerDerivedUnifiedBoard/Build/Products/Debug/AI Power.app` into `dist/` with a unique timestamp.

**Step 2: Report the verification evidence**

Share the updated app path and the commands that were actually run.
