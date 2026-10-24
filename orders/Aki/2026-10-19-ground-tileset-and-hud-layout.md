# ORDER — Fix Ground Tilemap and Debug HUD
- Agent: Aki
- Status: DONE
- Priority: P1
- Owner: Aki
- Branch/PR: aki/ground-tileset-and-hud-layout / TBD
- Dependencies: player_128 live (PR #25), dodge/jump + courtyard ground tile v1 (PR #26)

## Objective
Replace the single raised stone-cube tile currently tiled across the arena floor with a real
Godot TileSet/TileMapLayer ground (flat, continuous, varied, matching the owner's Kosen
close-combat reference). Fix the debug HUD so distinct info groups (title/build, player state,
camera/sprite, FPS/texture, controls) never overlap and read cleanly at 1280x720 and 1536x1024.

## Context / References
- Owner order (chat, 2026-10-19), reference/mockup/owner-close-combat-reference.png
- docs/visuals/CAMERA_AND_ART_DIRECTION.md (camera framing, locked visual intent)
- PR #26 shipped `assets/environment/kosen_courtyard/stone_tile_64.png` tiled via
  `draw_texture_rect(..., tile=true)` in training_arena.gd. On inspection this PNG is an
  isometric CUBE (flat top + two side faces + dark baseline), not a flat floor tile, so tiling
  it edge-to-edge reads as "repeated raised blocks" exactly as the owner describes. That is the
  root cause of Task 1.
- Kiro owns camera/occlusion (scripts/camera/camera_preset.gd, Block/BlockRear in
  training_arena.gd) — not touched by this order except reading `get_bounds()`.

## Scope / Files owned
- New: Godot TileSet resource + ground TileMapLayer, PixelLab-generated flat floor tile
  variants under `assets/environment/kosen_courtyard/`.
- `scripts/arena/training_arena.gd`: swap `draw_ground()`'s texture-rect tiling for a real
  TileMapLayer painted with deterministic (seeded) variation; keep bounds/walls/blocks untouched.
- `scripts/ui/debug_hud.gd`: restructure into Control containers/sections; add a collapsible
  technical-diagnostics panel; keep Tab-toggled Animation Lab working without overlap.
- Do not touch: scripts/camera/camera_preset.gd, scripts/player/player_controller.gd zoom/camera
  code, collision shapes, WorldScale constants, Kiro's Block/BlockRear occlusion.

## Deliverables
1. Dedicated branch/PR (this branch).
2. Reusable ground TileSet (small: base/alt/cracked/edge/dirt-transition/decorative) sourced
   from PixelLab, matching the owner's Kosen reference density/palette/perspective.
3. Debug HUD restructured into clear sections, no overlapping text, collapsible diagnostics.
4. Before/after screenshots.
5. Live browser preview after merge + deploy.
6. Short report in orders/Aki/reports/.

## Acceptance Criteria / Tests
- Ground reads as a continuous flat walkable surface with visible tile variation, no obvious
  repetition, no raised-block/floating-platform look.
- Wide and close camera presets both show the new ground correctly.
- Walk/run/sprint/dodge/jump across the new tiles: no collision regressions, no rendering gaps.
- HUD: title/build, player state, camera/zoom+sprite, FPS/texture mem, and controls are visually
  separated (no overlapping glyphs) at both 1280x720 and 1536x1024; diagnostics collapsible;
  Tab Animation Lab unaffected.
- `validate_godot_project.py` clean; `godot_ci.py tests` 493+/0; Web export + Playwright smoke
  test clean (no console errors); live Pages smoke test after deploy.

## Handoff / Notes
Escalate to Kiro only if a camera-specific behavior blocks ground/HUD testing; otherwise proceed
independently per the owner's explicit assignment of this order to Aki (including the tileset
art step, which would normally be Codex's lane but is explicitly tasked here).
