# Discover Cards Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `Discover` section backed by a remote `cards.json`, with local fallback cards and collapsed-on-failure behavior.

**Architecture:** Add a small feed model and loader to the app layer, thread discover state through `AppModel`, and render a compact card section in `MenuBarView`. Keep the first version static and manual, but model the feed as an array for future carousel support.

**Tech Stack:** Swift, SwiftUI, Foundation, URLSession, Swift Testing

---

### Task 1: Lock discover-state behavior with tests

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/AppModelTests.swift`

**Step 1: Write the failing test**

- Add one test proving a successful remote feed can make `Discover` visible and default-expanded.
- Add one test proving fallback content stays collapsed by default.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_discover_red --filter AppModelTests --package-path /Users/gaoshizai/work/ai_power`

Expected: failure because `AppModel` does not yet expose discover state.

**Step 3: Write minimal implementation**

- Add discover feed state and loader injection to `AppModel`.
- Load the feed when the panel opens.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_discover_green --filter AppModelTests --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 2: Add feed model and loader

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/DiscoverFeed.swift`
- Create: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/DiscoverFeedLoaderTests.swift`
- Create: `/Users/gaoshizai/work/ai_power/Config/Discover/cards.json`

**Step 1: Write the failing test**

- Add decode tests for feed and cards.
- Add a loader test proving invalid remote data falls back.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_discover_loader_red --filter DiscoverFeedLoaderTests --package-path /Users/gaoshizai/work/ai_power`

Expected: failure because the loader and model do not exist yet.

**Step 3: Write minimal implementation**

- Define feed/card models.
- Define loader protocol and live loader.
- Provide local fallback cards and a default remote URL.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_discover_loader_green --filter DiscoverFeedLoaderTests --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 3: Render the Discover section

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Modify: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MenuBarContentPresentationTests.swift`

**Step 1: Write the failing test**

- Add a focused presentation test for discover visibility rules if needed.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_discover_view_red --filter 'MenuBarContentPresentationTests|AppModelTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: failure until the view renders discover state.

**Step 3: Write minimal implementation**

- Add `Discover` disclosure section.
- Render the current card with CTA link.
- Add simple previous/next controls and compact position text.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_discover_view_green --filter 'MenuBarContentPresentationTests|AppModelTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

### Task 4: Final verification

**Files:**
- Verify current working tree only

**Step 1: Run targeted verification**

Run: `swift test --scratch-path /tmp/ai_power_discover_verify --filter 'AppModelTests|DiscoverFeedLoaderTests|MenuBarContentPresentationTests' --package-path /Users/gaoshizai/work/ai_power`

Expected: passing tests.

**Step 2: Run signed build verification**

Run: `cd /Users/gaoshizai/work/ai_power && ./scripts/build_signed_app.sh`

Expected: signed debug app builds successfully.
