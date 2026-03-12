# Warning Orbit Icon Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the warning-state app iconography with a shared orbit-X glyph and generate a signed debug app bundle.

**Architecture:** Keep warning state logic unchanged and swap only the rendered glyphs. Use one shared artwork helper for AppKit and SwiftUI so the menu bar badge and permission card stay visually consistent. Reuse the existing signed-build script to produce a development-signed app bundle after the UI change.

**Tech Stack:** SwiftUI, AppKit, Swift Testing, Xcode build scripts

---

### Task 1: Lock the warning icon contract with a failing test

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MenuBarIconDescriptorTests.swift`

**Step 1: Write the failing test**

- Change the warning-state assertion to expect the new custom orbit-X glyph contract instead of `exclamationmark`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter MenuBarIconDescriptorTests`

Expected: FAIL because production code still reports the old warning glyph.

### Task 2: Implement shared warning artwork

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/WarningOrbitArtwork.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarStatusController.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`

**Step 1: Add a small shared artwork helper**

- Build a reusable orbit-X shape/image generator with the orange palette needed for warning state.

**Step 2: Update menu bar rendering**

- Replace the warning `exclamationmark` branch with the custom orbit-X artwork while keeping idle/active rendering unchanged.

**Step 3: Update permission card rendering**

- Replace the card's system symbol with the same orbit-X artwork.

### Task 3: Verify app behavior still builds

**Files:**
- No code changes expected

**Step 1: Run targeted tests**

Run: `swift test --filter MenuBarIconDescriptorTests`

Expected: PASS

**Step 2: Run a debug build**

Run: `xcodebuild -project /Users/gaoshizai/work/ai_power/AIPower.xcodeproj -scheme AIPower -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Expected: `** BUILD SUCCEEDED **`

### Task 4: Produce a development-signed app bundle

**Files:**
- Reuse: `/Users/gaoshizai/work/ai_power/scripts/build_signed_app.sh`

**Step 1: Build signed app**

Run: `/Users/gaoshizai/work/ai_power/scripts/build_signed_app.sh`

Expected: script prints a signed app path

**Step 2: Verify signature**

Run: `codesign -dvv "<signed app path>"`

Expected: output shows an `Apple Development:` identity rather than `adhoc`
