# Glass Lens Ripple Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform `ripple.html` into a square glass-lens ripple exploration that can yield a strong static screenshot for a future macOS icon study.

**Architecture:** Keep the prototype self-contained in one HTML file. Replace the full-canvas ripple presentation with a centered square tile, add layered glass lighting treatments, then tune ripple geometry and timing so the animation contains a screenshot-worthy moment.

**Tech Stack:** HTML, CSS, SVG filters, SVG gradients, CSS keyframes

---

### Task 1: Reframe the composition into a square glass tile

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/ripple.html`

**Step 1: Define the target structure**

Update the page layout so the SVG presents a centered square tile rather than a full-screen ripple field.

**Step 2: Implement the square tile layers**

Add:

- rounded square glass panel
- background glow or vignette support
- tile edge highlight and shadow
- inner reflections that imply thickness

**Step 3: Verify visually in browser output**

Run a local rendering step and confirm the square tile is clearly legible before ripple details are tuned.

**Step 4: Keep the file self-contained**

Do not add external assets or scripts.

### Task 2: Rebuild the ripple rings as refractive bands

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/ripple.html`

**Step 1: Replace flat ring styling**

Change the current ring stack from simple grayscale strokes into refractive ripple bands with:

- bright crest edge
- darker trailing edge
- soft blur
- optional specular accent

**Step 2: Tune the geometry for a lens effect**

Adjust radii, stroke widths, and blur so the rings read as curved optical bands rather than thick outlines.

**Step 3: Keep the palette grayscale**

Use only white, gray, black, and alpha variation.

### Task 3: Refine animation for screenshot selection

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/ripple.html`

**Step 1: Update the animation curve**

Use easing and opacity transitions that create a clear “peak” frame during expansion.

**Step 2: Stagger multiple rings**

Layer ripple groups so at least one frame shows inner and outer bands interacting.

**Step 3: Preserve a calm loop**

The motion should feel premium and restrained rather than noisy.

### Task 4: Produce a local preview artifact

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/ripple.html`
- Create: `/Users/gaoshizai/work/ai_power/tmp/ripple-preview.png` (optional, generated artifact)

**Step 1: Open or render the updated prototype**

Use a local browser or headless capture path to inspect the result.

**Step 2: Capture one candidate frame**

Save a screenshot if tooling is available so the user can evaluate a still moment.

**Step 3: Report constraints**

If local screenshot tooling is unavailable, describe the strongest screenshot timing and any remaining limitations.

### Task 5: Interference-focused refinement

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/ripple.html`

**Step 1: Remove detached artifacts**

Delete the non-circular lower shadow arc and any similar loose shapes that break the concentric read.

**Step 2: Reduce attenuation**

Adjust animation opacity and scale timing so the outer rings remain visible longer.

**Step 3: Strengthen reflection pairs**

Add or rebalance circular bright/dark companion rings so the tile reads as reflective interference instead of a soft blur.

**Step 4: Regenerate preview**

Render a new thumbnail and compare it against the previous pass for clarity and coherence.
