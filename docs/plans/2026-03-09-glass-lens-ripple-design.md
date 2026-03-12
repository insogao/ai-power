# Glass Lens Ripple Design

## Context

The current prototype in `ripple.html` demonstrates grayscale expanding ripples on a flat neutral background. That version proves the core wave motion, but it still reads as an ambient illustration rather than an icon exploration for a macOS menu bar product.

This design pass shifts the visual language toward a square icon exploration frame with a transparent glass feel. The goal is not to finalize a 16-18pt menu bar glyph yet. The goal is to find a static moment from a dynamic study that can later be simplified into a menu bar symbol.

## Goal

Create a square visual exploration that suggests:

- a glass lens or polished transparent plate
- ripple diffraction and reflection inside that glass volume
- grayscale depth using highlight and shadow rather than color
- a dynamic animation that contains at least one screenshot-worthy moment

## Direction

The chosen direction is `glass lens`.

Instead of drawing realistic water waves across the whole frame, the composition centers on a circular optical core contained inside a square glass tile. The ripple rings behave like refracted light bands:

- bright leading edge
- darker trailing edge
- soft blur that fuses the ring into a curved glass surface

This should feel like a lens distorting light, not a flat line animation.

## Composition

The exploration frame becomes a centered square card with rounded corners.

- The square uses translucent fill and subtle inner/outer highlights to imply glass.
- The center contains a small luminous emitter.
- Around the emitter, 2-4 animated rings expand outward.
- The rings remain inside the square composition and should interact visually with the tile through shadow, glow, and faint distortion.

The background behind the tile should stay understated so the transparent layers remain readable.

## Lighting Model

The lighting direction is fixed:

- highlight from upper left
- shadow weight toward lower right

Each ripple ring should therefore use asymmetric brightness rather than a uniform stroke. The tile itself also uses edge reflection and inner shading to avoid looking like empty transparent space.

## Motion

The existing animation only scales ripples outward. The new motion should add subtle optical variation during expansion:

- brightness peaks shortly after emergence
- rings widen and soften as they move out
- overall opacity fades without disappearing too abruptly

The animation remains looped for exploration, but the composition must contain a strong still frame suitable for screenshot selection.

## Constraints

- Keep the implementation inside `ripple.html`
- Use SVG and CSS only
- Preserve a clean square composition for screenshotting
- Stay grayscale with transparency cues
- Optimize for visual exploration, not menu bar fidelity yet

## Success Criteria

The exploration is successful if:

1. The square frame clearly reads as glass rather than flat gray.
2. The ripple rings feel reflective and refractive, not merely blurred circles.
3. At least one still moment looks plausible as the basis for a future app icon study.
4. The effect remains readable without relying on saturated color.

## Notes

This document is saved locally as required by the brainstorming workflow. A git commit is intentionally skipped because this repository currently has no initial commit history and this task is an exploratory prototype update.

## Iteration Notes

User feedback on the first pass identified two concrete issues:

- the lower detached gray arc reads as contamination instead of reflection
- the ripple attenuation is too aggressive, so the tile loses reflective interference structure

The next iteration therefore tightens the visual rules:

- remove all detached lower gray arcs
- keep reflections circular and optically centered
- reduce decay so outer rings linger longer
- increase alternating bright and dark ring pairs to create a more obvious interference feel
