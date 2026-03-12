# AI Continuity Helper Packaging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate AI Continuity from a SwiftPM-only prototype into a signed macOS app bundle layout with an embedded LaunchDaemon, XPC scaffolding, and a UI path that targets the real helper flow instead of the temporary AppleScript fallback.

**Architecture:** Keep the current SwiftPM libraries and tests as the source of truth for business logic, helper recovery, and monitoring. Add a native app-bundle packaging layer on top: an Xcode project spec, LaunchDaemon resources, a shared XPC contract, and a helper daemon executable that can serve arm/restore/status requests once installed through `SMAppService`.

**Tech Stack:** Swift 6, SwiftUI, Foundation, ServiceManagement, NSXPCConnection, XcodeGen, launchd plist resources, Swift Testing

---

### Task 1: Add the packaging and IPC plan to the codebase

**Files:**
- Create: `docs/plans/2026-03-07-ai-continuity-helper-packaging.md`

**Step 1: Write the plan document**

Capture the migration scope, target files, helper lifecycle, and verification commands.

**Step 2: Commit**

```bash
git add docs/plans/2026-03-07-ai-continuity-helper-packaging.md
git commit -m "docs: add AI continuity packaging plan"
```

### Task 2: Define a shared XPC contract

**Files:**
- Modify: `Package.swift`
- Create: `Sources/AIPowerIPC/ContinuityXPC.swift`
- Create: `Tests/AIPowerIPCTests/ContinuityXPCContractTests.swift`

**Step 1: Write the failing test**

Add tests proving:
- the Mach service name is stable
- supported daemon actions round-trip to user-visible labels
- reply payloads preserve helper status and recovery text

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_tdd_ipc --filter ContinuityXPCContractTests`
Expected: FAIL because the IPC target does not exist.

**Step 3: Write minimal implementation**

Create a shared IPC target with:
- Mach service constants
- XPC request / reply model classes
- an Objective-C compatible daemon protocol for `status`, `apply`, `restore`, and `fetchRecoveryState`

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_tdd_ipc --filter ContinuityXPCContractTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Package.swift Sources/AIPowerIPC Tests/AIPowerIPCTests
git commit -m "feat: add continuity XPC contract"
```

### Task 3: Replace the temporary admin fallback in the app service layer

**Files:**
- Create: `Tests/AIPowerSystemTests/SMAppContinuityServiceTests.swift`
- Modify: `Package.swift`
- Modify: `Sources/AIPowerSystem/SystemSupport.swift`

**Step 1: Write the failing test**

Add tests proving:
- `SMAppContinuityService` maps `SMAppService` registration status to the expected helper status
- it routes `arm`, `restore`, and `fetchRecoveryState` through an injected XPC client
- the default helper manager prefers the real SMApp service path

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_tdd_system --filter SMAppContinuityServiceTests`
Expected: FAIL because the XPC-backed service abstraction does not exist.

**Step 3: Write minimal implementation**

Introduce:
- an injectable `ContinuityDaemonClient` abstraction
- an XPC-backed implementation that connects to the shared Mach service
- a refactored `SMAppContinuityService` that uses `SMAppService.daemon(plistName:)`
- a default `LocalContinuityHelperManager` wired to `SMAppContinuityService`

Keep the interactive AppleScript service available only as a non-default debug fallback.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_tdd_system --filter SMAppContinuityServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Package.swift Sources/AIPowerSystem Tests/AIPowerSystemTests
git commit -m "feat: route continuity through SMApp service"
```

### Task 4: Turn the helper executable into a daemon-capable XPC listener

**Files:**
- Create: `Tests/AIPowerHelperSupportTests/ContinuityDaemonServerTests.swift`
- Modify: `Sources/AIPowerHelperSupport/HelperModels.swift`
- Modify: `Sources/AIPowerContinuityHelper/main.swift`

**Step 1: Write the failing test**

Add tests proving:
- daemon action execution maps helper intent to `pmset` commands
- a recovery journal is saved on arm and cleared on restore
- status replies expose the current recovery reason

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path /tmp/ai_power_tdd_daemon --filter ContinuityDaemonServerTests`
Expected: FAIL because the daemon server types do not exist.

**Step 3: Write minimal implementation**

Create:
- a reusable daemon command handler that wraps `ContinuityHelperEngine`
- an `NSXPCListener` delegate for the Mach service
- a helper main entry point that can either serve XPC or continue to support CLI testing

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path /tmp/ai_power_tdd_daemon --filter ContinuityDaemonServerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIPowerHelperSupport Sources/AIPowerContinuityHelper Tests/AIPowerHelperSupportTests
git commit -m "feat: add continuity daemon XPC listener"
```

### Task 5: Add an Xcode project spec and embedded LaunchDaemon resources

**Files:**
- Create: `project.yml`
- Create: `Config/App/Info.plist`
- Create: `Config/App/AIPowerApp.entitlements`
- Create: `Config/Daemon/com.aipower.continuity-helper.plist`
- Create: `Config/Daemon/AIPowerContinuityHelper.entitlements`
- Create: `scripts/generate_xcodeproj.sh`

**Step 1: Write the configuration**

Create an XcodeGen spec that:
- builds the menu bar app bundle
- embeds the LaunchDaemon plist under `Contents/Library/LaunchDaemons`
- builds the helper executable at the bundle-relative path referenced by `BundleProgram`
- signs with the local development team

**Step 2: Generate the Xcode project**

Run: `./scripts/generate_xcodeproj.sh`
Expected: an `AIPower.xcodeproj` is generated without schema errors.

**Step 3: Commit**

```bash
git add project.yml Config scripts
git commit -m "build: add Xcode project spec for app and daemon"
```

### Task 6: Final verification

**Files:**
- Review: `project.yml`
- Review: `Sources/AIPowerSystem/SystemSupport.swift`
- Review: `Sources/AIPowerContinuityHelper/main.swift`

**Step 1: Run automated verification**

Run:
- `swift test --scratch-path /tmp/ai_power_verify_test`
- `swift build --scratch-path /tmp/ai_power_verify_build`

Expected:
- all tests pass
- all SwiftPM targets build successfully

**Step 2: Generate the Xcode project**

Run:
- `./scripts/generate_xcodeproj.sh`

Expected:
- `AIPower.xcodeproj` exists
- LaunchDaemon plist and helper target are referenced in the project

**Step 3: Manual local validation**

Open the project in Xcode and confirm:
- the app target resolves the `Apple Development: jian gao (QTQCW2J4HY)` signing identity
- the LaunchDaemon target builds
- the menu app starts and `AI Continuity` now reports helper registration state from `SMAppService`

**Step 4: Commit**

```bash
git add .
git commit -m "feat: package AI continuity helper for signed app bundles"
```
