# App State Logo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert the logo prototype into a repeatable two-state app icon generator and replace the app's bundle icon with the exported waveform instrument logo.

**Architecture:** Extract state definitions and SVG generation into a shared JavaScript module. Use that module from the browser preview and from a Node export script that emits the final SVG/PNG assets plus a macOS `AppIcon.appiconset`.

**Tech Stack:** HTML, browser JavaScript modules, Node.js, SVG, `qlmanage`, `sips`, XcodeGen

---

### Task 1: Define the shared logo generator with TDD

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/scripts/logo_generator.js`
- Create: `/Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`

**Step 1: Write the failing test**

Add Node tests that assert:

- `Busy` and `Idle` state configs exist
- `Busy` uses higher amplitude than `Idle`
- generated SVG includes a circular composition and waveform path

**Step 2: Run test to verify it fails**

Run: `node --test /Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`
Expected: FAIL because the generator module does not exist yet

**Step 3: Write minimal implementation**

Create the shared generator module with:

- state definitions
- wave path generation
- SVG string generation

**Step 4: Run test to verify it passes**

Run: `node --test /Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`
Expected: PASS

### Task 2: Update the browser preview and export controls

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/logo.html`

**Step 1: Replace toy controls with state-focused controls**

Center the page around:

- `Busy` preview
- `Idle` preview
- one export action for final assets

**Step 2: Reuse the shared generator**

Import the shared module into the page and render the selected states from the same code used in export.

**Step 3: Keep the preview aligned to final assets**

Remove controls that are no longer part of the deliverable:

- arbitrary color picker
- alternate waveform shape selector
- 3-frame animation export flow

### Task 3: Generate exported assets

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/scripts/export_app_state_icons.js`
- Create: `/Users/gaoshizai/work/ai_power/Assets/AppStateIcons/app_state_busy.svg`
- Create: `/Users/gaoshizai/work/ai_power/Assets/AppStateIcons/app_state_busy.png`
- Create: `/Users/gaoshizai/work/ai_power/Assets/AppStateIcons/app_state_idle.svg`
- Create: `/Users/gaoshizai/work/ai_power/Assets/AppStateIcons/app_state_idle.png`

**Step 1: Write the failing test**

Extend or add a test that verifies the exporter requests both states and writes deterministic filenames.

**Step 2: Run test to verify it fails**

Run: `node --test /Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`
Expected: FAIL because exporter helpers are not implemented yet

**Step 3: Write minimal implementation**

Add a Node export script that:

- generates both state SVGs
- rasterizes them to PNG
- writes them to stable asset paths

**Step 4: Run test to verify it passes**

Run: `node --test /Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`
Expected: PASS

### Task 4: Replace the app icon asset

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `/Users/gaoshizai/work/ai_power/project.yml` (if explicit resource wiring is needed)

**Step 1: Generate the app icon set**

Create the required macOS icon sizes from the exported `Busy` PNG.

**Step 2: Regenerate the Xcode project**

Run: `/Users/gaoshizai/work/ai_power/scripts/generate_xcodeproj.sh`
Expected: project includes the new asset catalog

**Step 3: Verify file presence**

Confirm the iconset contains the expected PNG files and `Contents.json`.

### Task 5: Verify the asset pipeline

**Files:**
- Verify only

**Step 1: Run generator tests**

Run: `node --test /Users/gaoshizai/work/ai_power/scripts/logo_generator.test.js`

**Step 2: Run the export script**

Run: `node /Users/gaoshizai/work/ai_power/scripts/export_app_state_icons.js`

**Step 3: Validate generated metadata**

Run:

- `plutil -lint /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `find /Users/gaoshizai/work/ai_power/Sources/AIPowerApp/Assets.xcassets/AppIcon.appiconset -maxdepth 1 -type f | sort`

**Step 4: Build confidence**

If the local environment allows it, run an app build after project regeneration and confirm the asset catalog is accepted.
