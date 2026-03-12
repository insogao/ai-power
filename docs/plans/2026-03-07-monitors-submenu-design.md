# Monitors Submenu Design

## Goal

Move AI Mode configuration out of `Debug` and into a first-class `Monitors` submenu-style section so users can see and edit monitored applications and ports without guessing whether adds succeeded.

## UX Direction

- Keep the main menu compact.
- Add a top-level `Monitors` disclosure row that behaves like a submenu summary.
- Show a short summary on the collapsed row, e.g. `Apps 7 • Ports 2`.
- When expanded, show two grouped sections:
  - `Applications`
  - `Ports`
- Each section shows the current effective list before the input row.
- Adding a value updates the visible list immediately.
- Failed adds show a short inline message such as `Already added` or `Invalid port`.

## Scope

- Move application and port configuration UI out of `Debug`.
- Keep `Debug` for helper/environment/log diagnostics only.
- Reuse existing `AppModel` add methods and published state.
- Do not build a separate window or preferences screen.
- Do not add delete/reorder in this pass.

## Interaction Rules

- `Monitors` collapsed:
  - show only a single summary row
- `Monitors` expanded:
  - `Applications` section shows built-in plus custom items
  - `Ports` section shows built-in plus custom items
  - each section has a text field and `Add` button
- After adding:
  - on success: clear the field and refresh the list
  - on failure: keep the field value and show inline feedback

## Testing

- Verify the new `Monitors` section renders summary text.
- Verify `Debug` no longer contains configuration fields.
- Verify adding a custom app updates the visible app list.
- Verify adding a custom port updates the visible port list.
- Verify invalid/duplicate input shows feedback.
