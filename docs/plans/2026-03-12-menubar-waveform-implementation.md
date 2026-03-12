# Menu Bar Waveform Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the menu bar idle/active bolt glyphs with waveform artwork and rebuild a signed app bundle.

**Architecture:** Keep the existing menu bar icon state machine and swap only the glyph rendering for idle and active states. Reuse shared drawing helpers so the waveform badge is rendered consistently anywhere the menu bar icon is built, while leaving warning state on the orbit-X artwork.

**Tech Stack:** SwiftUI, AppKit, Swift Testing, Xcode build scripts

---

### Task 1: Lock the idle/active icon contract with failing tests

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MenuBarIconDescriptorTests.swift`

**Step 1: Write the failing test**

- Change idle and active expectations from bolt symbols to waveform glyphs.

**Step 2: Run test to verify it fails**

Run: `swift test --filter MenuBarIconDescriptorTests`

Expected: FAIL because production code still returns bolt glyphs.

### Task 2: Implement waveform badge artwork

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/WaveformBadgeArtwork.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarStatusController.swift`

**Step 1: Add a small shared waveform artwork helper**

- Draw a simplified waveform that stays readable in the menu bar badge.

**Step 2: Switch idle and active descriptors to waveform glyphs**

- Keep warning on orbit-X.

**Step 3: Tune badge colors**

- Update idle/active badge backgrounds and waveform colors to match the app's wave logo language.

### Task 3: Verify build and tests

**Files:**
- No new files expected

**Step 1: Run targeted tests**

Run: `swift test --filter MenuBarIconDescriptorTests`

Expected: PASS

**Step 2: Run a debug build**

Run: `xcodebuild -project /Users/gaoshizai/work/ai_power/AIPower.xcodeproj -scheme AIPower -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Expected: `** BUILD SUCCEEDED **`

### Task 4: Produce a signed app bundle

**Files:**
- Reuse: `/Users/gaoshizai/work/ai_power/scripts/build_signed_app.sh`

**Step 1: Build signed app**

Run: `/Users/gaoshizai/work/ai_power/scripts/build_signed_app.sh`

Expected: script prints a signed app path
