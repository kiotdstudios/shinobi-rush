# REPORT — Camera/scale validation vs. owner reference (2026-10-18, revised)
- Order: orders/Aki/2026-10-18-camera-scale-validation.md
- Branch: aki/camera-scale-validation (merged latest `main` mid-task, see "Course correction" below)

## Course correction (read this first)
Partway through this task, the owner pushed two doc commits directly to `main`
(`docs/visuals/CAMERA_AND_ART_DIRECTION.md`, `docs/GAME_DESIGN_DOCUMENT.md`, 2026-10-19) that:
1. Lock the target at **16–19% of viewport height** for the standing player (115–137px at 720p) — not the
   ~20% I had independently measured off the reference screenshot.
2. Explicitly say the shared `WorldScale.CAMERA_BASE_ZOOM` (and Kiro's prior wide-camera PR) is a
   **prototype baseline, not locked final framing**, and that I should use "a configurable camera preset
   or isolated comparison scene" — i.e. not edit the constant every other scene (including the live
   `scenes/main.tscn` / `scenes/arena/training_arena.gd`) depends on.

My first pass had directly retuned `CAMERA_BASE_ZOOM` in place and edited the live, shared
`training_arena.gd` (which `main.tscn` instances directly) — exactly what the new doc says not to do. I
reverted all of that (zoom constant back to `1.0/SCALE`, `training_arena.gd`/`tests/run_tests.gd`/
`scripts/ci/smoke/controls-probe.mjs` all back to `main`'s version) and rebuilt the validation as a
genuinely isolated scene. **No merge to `main` happened with the wrong numbers** — the one PR I had opened
and then merged on the first pass is effectively superseded by this corrected version; see "Status" below
for what's actually live.

## What this delivers (corrected)
- New, additive-only files — nothing shared or Kiro-owned is touched:
  - `scripts/validation/camera_scale_validation.gd` + `scenes/validation/camera_scale_validation.tscn`:
    composes the existing, **unmodified** `training_arena.tscn` + `player.tscn` (same composition
    `scenes/main.tscn` uses), then layers on a ground-texture overlay, two gate pillars, and a bandit
    placeholder, and overrides *this scene's own* camera zoom. `scripts/arena/training_arena.gd`,
    `scenes/main.tscn`, and `scripts/web/web_bridge.gd` (Kiro's) are all byte-identical to `main`.
  - `scripts/world_scale.gd`: one new constant, `VALIDATION_CAMERA_ZOOM := 126.0/108.0`, added alongside
    the untouched `CAMERA_BASE_ZOOM` — purely additive, used only by the new validation scene.
  - `assets/environment/kosen_courtyard/stone_tile_64.png`: PixelLab-generated Kōsen stone courtyard tile
    (64×64), used only by the validation scene's ground overlay.
- `tests/run_tests.gd` and `scripts/ci/smoke/controls-probe.mjs`: **unchanged from `main`** (my earlier
  edits to their camera-baseline assertions were reverted along with the constant change they were
  matching).

## Math (reference-derived, within the owner-locked band)
- Owner-locked target band: 16–19% of viewport height. Midpoint used: 17.5% of 720px = **126px**.
- Native placeholder body height (`WorldScale.BODY_HEIGHT`) = 108px at zoom 1.0.
- `VALIDATION_CAMERA_ZOOM` = 126 / 108 = **1.1667**.
- Visible world rect at that zoom on 1280×720: ≈ 1097×617 world units.

## Measured result (empirical, from the actual capture)
- Captured by temporarily pointing a **local-only** export's `run/main_scene` at the new validation scene
  (never committed — reverted immediately after export, confirmed via `git diff --stat project.godot`
  showing no change), served over HTTP, Playwright + `canvas.toDataURL()` at 1280×720.
- Player figure measured in the screenshot: head-top ≈ y=232, feet ≈ y=362 → **130px tall, 18.1% of
  viewport height** — inside the owner's locked 16–19% band.
- Scene zoom used: **1.1667**.

## Screenshots
- `orders/Aki/reports/2026-10-18-camera-scale-validation-screenshot.png` — 1280×720 capture of the
  isolated validation scene: player placeholder centered, Kōsen gate pillars flanking the walkway, bandit
  placeholder to the south-east, stone-tile ground, all in frame together.
- `orders/Aki/reports/2026-10-18-camera-scale-validation-comparison.png` — side-by-side against the
  owner's reference (reference scaled to the same 720px height, placed left; our capture right).

## What this is NOT
- Still the procedural placeholder figure, not Codex's approved 128×128 art (separate, still-pending
  track: `orders/Codex/2026-10-18-idle-128-production-handoff.md`). Per the owner's own doc: "validate
  with the actual approved Codex sprite rather than assuming the 128px frame equals character height" —
  so this zoom number should be treated as provisional until re-checked against real art.
- Not a change to the live gameplay camera. `WorldScale.CAMERA_BASE_ZOOM` and the actual gameplay scene
  are untouched; this is purely a preview/validation artifact.
- Not the full MVP map. Forest A/B, the real Kōsen Gate environment, and `world/maps/MVP_WORLD_MAP.md`
  layout remain deferred pending explicit owner approval, per the order and the owner's own doc.

## Kiro coordination
No files Kiro owns or the live game depends on were touched: `scripts/arena/training_arena.gd`,
`scenes/main.tscn`, `scripts/web/web_bridge.gd`, and everything under `orders/Kiro/**` are byte-identical
to `main`.

## Tests
- `python scripts/ci/validate_godot_project.py --project .`: PASS, 0 errors/warnings.
- `python scripts/ci/godot_ci.py tests --project . --godot <godot>`: **419 passed, 0 failed**, run against
  the unmodified live project (confirms the validation scene has zero effect on the shared game/tests).

## Live / local preview
**Not merged to `main`.** The branch `aki/camera-scale-validation` is pushed to origin for review, but
since this round's whole point is to avoid landing an unapproved camera change on the shared/live scene,
I'm not opening a path to deploy it to GitHub Pages (which only serves `scenes/main.tscn`, unaffected
anyway). For approval, the fastest path is a **local playable preview on this machine**: I can serve the
exported validation build on localhost and open it directly, or re-run it on request — say so and I'll
spin it back up.

## Status
Order status → **REVIEW**. Awaiting owner's visual approval of camera distance / character prominence /
environment proportions (now inside the locked 16–19% band) before any full MVP build (Forest A/B, full
Kōsen Gate, `MVP_WORLD_MAP.md` layout), and before anything here touches the live `CAMERA_BASE_ZOOM` or
`training_arena.gd`.
