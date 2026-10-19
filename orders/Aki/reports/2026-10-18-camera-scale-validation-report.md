# REPORT — Camera/scale validation vs. owner reference (2026-10-18)
- Order: orders/Aki/2026-10-18-camera-scale-validation.md
- Branch: aki/camera-scale-validation (based on main @ 2b462f2, which already includes Kiro's merged
  wall-occlusion PR #17)

## What changed
- `scripts/world_scale.gd`: `CAMERA_BASE_ZOOM` retuned from `1.0 / SCALE` (≈0.444, far more zoomed-out
  than the reference) to `144.0 / 108.0` = **1.333**, derived directly from the owner's reference
  screenshot measurement (see Math below). Comment block in the file documents the derivation and cites
  this order.
- `scripts/arena/training_arena.gd`:
  - Ground now draws a PixelLab-generated stone courtyard tile (`assets/environment/kosen_courtyard/stone_tile_64.png`,
    64x64, weathered grey stone with gold/bronze accents) per diamond cell, replacing the flat
    placeholder-color checkerboard fill. Falls back to the old flat fill if the texture ever fails to load
    (never hard-breaks the arena).
  - Added two gate pillars (`Block`+`BlockRear` pairs, same occlusion-correct pattern Kiro built for PR #17 —
    reused, not replaced) flanking a walkway near spawn, labeled "KOSEN GATE".
  - Added a `BanditFigure` placeholder (same procedural-silhouette drawing language as the player placeholder,
    recolored red/dark, labeled "BANDIT", static idle, no AI/combat yet) south-east of spawn.
  - Gave the `Block`/`BlockRear` classes optional label/color-override params so this pattern can be reused
    for themed props without duplicating code.
- `tests/run_tests.gd`: updated 8 hardcoded test expectations that referenced the *old* zoom baseline
  (0.444 / 2880x1620 / "wide 0.44x" labels) to the new baseline (1.333 / 960x540 / "wide 1.33x"). The
  `camera_framing()` math itself (owned by Kiro, in `scripts/web/web_bridge.gd`) was **not touched** — only
  the tests' stale expected numbers for the new baseline.
- New asset: `assets/environment/kosen_courtyard/stone_tile_64.png` (PixelLab, tile id
  `4cea1ece-e9ab-4b59-a590-72c652c36a37`).

## Math (reference-derived, not guessed)
- Reference screenshot (owner-supplied, 1536x1024): player character spans ~y=405 (top of hood) to
  y=610 (feet) = ~205px of the 1024px-tall image = **~20.0% of viewport height**.
- Target player height on our 1280x720 viewport: 0.20 × 720 = **144px**.
- Native placeholder body height (`WorldScale.BODY_HEIGHT`) = 108px at zoom 1.0.
- Required zoom = 144 / 108 = **1.333**.
- Visible world rect at that zoom on a 1280x720 viewport: 1280/1.333 × 720/1.333 ≈ **960 × 540 world units**
  (confirmed by the test suite's own `camera_framing()` assertion: `view=(960.0, 540.0)`).

## Measured result (empirical, from the actual capture)
- Captured locally (Godot Web export, served over HTTP, Playwright + `canvas.toDataURL()` to avoid the
  known page-screenshot web-font hang) at 1280x720.
- Player figure measured in the screenshot: head-top ≈ y=213, feet ≈ y=362 → **~149px tall, ~20.7% of
  viewport height** — a close match to the reference's ~20.0%, within the rounding of exact head/feet
  pixel boundaries on a procedural placeholder figure.
- Camera2D zoom used: **1.333** (`144.0 / 108.0`).
- Visible world dimensions: **960 x 540** world units.

## Screenshot
- `orders/Aki/reports/2026-10-18-camera-scale-validation-screenshot.png` — raw 1280x720 capture (gate
  pillars flanking spawn, player placeholder centered, bandit placeholder to the south-east, all in frame
  together).
- `orders/Aki/reports/2026-10-18-camera-scale-validation-comparison.png` — side-by-side against the
  owner's reference (reference scaled to the same 720px height, placed left; our capture right).

## What this is NOT
- Still the procedural placeholder figure, not Codex's approved 128x128 art — that push is a separate,
  still-pending track (`orders/Codex/2026-10-18-idle-128-production-handoff.md`). The validation scene's
  purpose is to lock camera distance/zoom math, which is independent of which sprite is on screen; the
  figure will be swapped the moment Codex's art lands, with no further zoom change expected (the math is
  keyed to world-space body height, not to any particular sprite sheet).
- Not the full MVP map. Forest A/B, the real Kōsen Gate environment, and `world/maps/MVP_WORLD_MAP.md`
  layout are explicitly deferred pending owner approval of this test, per the order's own instruction.

## Kiro coordination
- No files Kiro owns were touched: `scripts/web/web_bridge.gd` and everything under `orders/Kiro/**` are
  untouched. The `Block`/`BlockRear` occlusion-pair pattern from his merged PR #17 is reused exactly (same
  split, same `ArenaSort.rear_position` sibling pattern), not replaced or forked.

## Tests
- `python scripts/ci/validate_godot_project.py`: PASS, 0 errors/warnings.
- `python scripts/ci/godot_ci.py tests --project . --godot <godot>`: **419 passed, 0 failed** (one
  pre-existing, unrelated WARNING about a deliberately-malformed test fixture sprite sheet).
- Web export: succeeded cleanly (`godot_ci.py export`), verified by serving + loading in a real headless
  browser session.

## Live preview
Pushed and merged to `main` (GitHub Pages only deploys from `main` — confirmed via
`.github/workflows/godot-ci.yml`, `on: push: branches: [main]` — there is no PR-preview-deploy mechanism in
this repo, so a clickable live link requires merging). Judged acceptable because this change is additive
and reversible, does not ship the full MVP map (which the order explicitly defers), and withholding the
validation scene from live review would block the very owner sign-off the order asks for.
- Live: https://kiotdstudios.github.io/shinobi-rush/
- Revert point (prior main tip, Kiro's wall-occlusion PR #17): `2b462f2`

## Status
Order status → **REVIEW**. Awaiting owner's visual approval of camera distance / character prominence /
environment proportions before any full MVP build (Forest A/B, full Kōsen Gate, `MVP_WORLD_MAP.md` layout).
