# Menu Bar Unified Board Design

**Goal:** Keep one shared menu bar background board across idle, active, and warning states while enlarging the waveform and warning glyphs so the symbol reads clearly at 18px.

## Approved Direction

- Keep the existing rounded-square background board and its dark textured feel.
- Remove the visual sense that the symbol is constrained by an inner circular range.
- Enlarge the teal waveform for idle and active states.
- Enlarge the orange orbit-X warning mark without giving warning its own orange background.

## Constraints

- The menu bar icon still has to read at 18px.
- The board should stay visually consistent with the current app language.
- The glyph should carry the state difference; the board should not.

## Recommendation

Use one shared badge board for all menu bar states:

- Reuse the same dark gradient board and neutral border for idle, active, and warning.
- Make the waveform and orbit-X draw closer to the board edges.
- Reduce internal padding inside both glyph renderers so the symbol occupies more of the board.
