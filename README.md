# AI Power

AI Power is a native macOS menu bar app that keeps your Mac running when AI work is actually happening.

It is built for developers who use tools like Codex, Claude Code, Cursor, VS Code, Kimi, local gateways, and long-running AI workflows on MacBook, Mac mini, and desktop Macs.

## Why AI Power

Traditional keep-awake apps are either fully manual or always on.

AI Power takes a different approach:

- It focuses on AI coding and agent workflows.
- It can keep tasks alive during screen-off, lock-screen, and closed-lid scenarios.
- It tries to get out of the way when work stops.
- It gives you simple menu bar controls instead of a heavy settings app.

## What It Does

- `AI Mode`
  Detects AI-related activity and keeps your Mac awake only when needed.

- `Timed Keep Awake`
  Keep the Mac awake for a fixed duration like `30m`, `1h`, `3h`, `8h`, `1d`, `3d`, or `∞`.

- `Closed-Lid Continuity`
  On supported setups, AI Power can keep tasks running after lid-close or when the display is off.

- `Fine-Grained Wake Controls`
  Choose whether to prevent:
  - computer sleep
  - display dimming / display sleep
  - lock screen

- `AI Tool Monitoring`
  Built-in monitoring for common AI development tools, plus custom application keywords and custom ports.

- `Menu Bar First`
  The full workflow lives in the menu bar: mode switching, timing, monitoring, permissions, and diagnostics.

## Built For These Workflows

- Coding with Codex, Claude Code, Cursor, VS Code, Windsurf, Kimi, Gemini, Qwen, and similar tools
- Long-running terminal tasks and AI agent sessions
- Local gateways and localhost AI services
- Overnight generation, indexing, search, download, or batch automation tasks
- Mac mini / desktop workflows where the screen turns off but work should continue

## Product Highlights

- Native macOS app built with Swift and SwiftUI
- Menu bar control surface with low-friction interaction
- Smart AI-aware keep-awake behavior
- Closed-lid continuity support for laptop workflows
- Configurable idle grace window in AI Mode
- Discover panel for lightweight project and ecosystem promotion

## Current Status

AI Power is under active development.

The current build already includes:

- AI Mode
- timed keep-awake controls
- `∞` keep-awake mode
- wake-control options
- custom monitored applications and ports
- helper-based continuity flow
- Discover panel driven by remote `cards.json`

## Build From Source

### Requirements

- macOS 14+
- Xcode 26+
- An Apple Development signing certificate if you want the signed helper flow

### Unsigned Debug Build

```bash
xcodebuild -project /Users/gaoshizai/work/ai_power/AIPower.xcodeproj \
  -scheme AIPower \
  -configuration Debug \
  -derivedDataPath /tmp/AIPowerUnsignedDiscoverBuild \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Then launch:

```bash
open "/tmp/AIPowerUnsignedDiscoverBuild/Build/Products/Debug/AI Power.app"
```

### Signed Debug Build

```bash
APPLE_DEVELOPMENT_IDENTITY="Apple Development: jian gao (QTQCW2J4HY)" ./scripts/build_signed_app.sh
```

Then launch:

```bash
open "/tmp/AIPowerSignedBuildLocal/Build/Products/Debug/AI Power.app"
```

## Permissions

Some advanced continuity features require macOS approval:

- helper installation
- background / login item approval
- closed-lid continuity approval flow

AI Power is designed to keep these prompts visible and explainable in the menu bar UI instead of hiding them behind silent failure.

## Distribution Plan

Planned distribution channels:

- GitHub Releases with signed `.dmg`
- Homebrew Cask

## Discover Feed

The in-app `Discover` section is powered by a remote JSON feed.

Current public feed format supports:

- `enabled`
- `default_expanded`
- ordered card arrays
- localized card copy

This makes it possible to update in-app promotion content without shipping a new app build.

## Roadmap

- Signed DMG release packaging
- Homebrew Cask distribution
- Better onboarding and permission guidance
- Richer Discover cards
- More polished release pipeline

## License

AI Power is currently released under the custom `AI Power Community License 1.0`.

In practical terms:

- source code is visible;
- personal use is allowed;
- internal use inside companies and organizations is allowed at no charge; and
- resale, competing commercial distribution, app-store redistribution, and
  similar external commercialization require separate written permission.

See [LICENSE](LICENSE) for the full terms.

## Relay-lab

AI Power is being prepared as part of the broader `Relay-lab` software portfolio:

[Relay-lab](https://github.com/Relay-lab)
