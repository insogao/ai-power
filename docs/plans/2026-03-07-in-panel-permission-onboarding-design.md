# In-Panel Permission Onboarding Design

## Context

The current permission flow mixes two surfaces:

- the menu bar popover
- external `NSAlert` dialogs

That split creates two user-facing problems:

- permission guidance appears disconnected from the control the user just touched
- the dialog content can momentarily render with incomplete actions, which looks broken

The intended interaction is simpler: if AI Continuity needs setup, the app should bring the user into one obvious place and guide them through the next required action.

## Product Direction

Permission onboarding moves fully into the menu bar panel.

When the app first launches into a mode that requires AI Continuity and the helper is not ready, the menu bar panel should auto-open once. The panel shows a dedicated permission card above the main status area. That card explains the current requirement and exposes exactly one next action.

There is no `Not Now` button. If the user does not want to continue, they can dismiss the panel normally.

## User Flow

### First-Time Setup

1. App launches.
2. If the current selection requires continuity and helper access is not ready, the panel opens automatically.
3. The panel shows:
   - a short explanation
   - one action button: `Install Helper`
4. After install succeeds and the system moves to approval-required state, the same panel updates to:
   - a short explanation
   - one action button: `Open Settings`
5. Once helper status becomes `ready`, the permission card disappears.

### Later Visits

- Changing from one timed duration to another does not reopen or re-prompt.
- Clicking the warning icon or reopening the panel shows the same in-panel permission card if approval is still pending.
- The explicit action button remains available so the user can retry intentionally.

## State Model

The panel should show only the next required permission action:

- `notInstalled` or `degraded` -> show install card
- `requiresApproval` -> show approval card
- `ready` -> hide permission card

The app still keeps internal helper states, but the view should not surface implementation terms such as “registration missing”.

## UI Rules

- No external `NSAlert` permission dialogs.
- No `Not Now` action.
- No delayed button mutation from `Not Now` to `Continue` or `Open Settings`.
- The permission card should render synchronously from app state.
- The card should appear near the top of the panel so it is visible immediately after auto-open.

## Engineering Approach

- `AppModel` becomes the single source of truth for onboarding presentation.
- A small in-panel permission card model will replace ad-hoc alert prompts.
- `MenuBarStatusController` gains a lightweight way to auto-open the popover once when onboarding is needed.
- The onboarding auto-open is edge-triggered, not repeated on every mode change.

## Test Plan

1. Startup with helper `notInstalled`
   - panel auto-opens once
   - permission card shows `Install Helper`

2. After helper install returns `requiresApproval`
   - no external alert appears
   - same panel now shows `Open Settings`

3. Change timed duration while still `requiresApproval`
   - no repeated auto-open
   - no repeated external prompt
   - permission card remains the only recovery path

4. Transition to `ready`
   - permission card disappears
   - panel no longer auto-opens on launch
