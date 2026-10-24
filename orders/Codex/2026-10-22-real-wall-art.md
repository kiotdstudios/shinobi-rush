# ORDER — Real wall art to replace the placeholder walls and blocks
- Agent: Codex
- Status: QUEUED
- Priority: P0 — direct owner request ("change these placeholder walls and get some real ones in game matching our reference and game style quality")
- Owner: Codex (environment art). Aki integrates the finished textures into the arena (see Handoff).
- Branch/PR: `codex/wall-art`
- Dependencies: Codex grass tiles (in progress) should share the same palette/lighting; current `main`.

## Objective
Replace every gray "PLACEHOLDER" box in the arena (the long walls, the rocks, the crate) with real, game-quality pixel art that matches the owner's stone-tile reference and the floor/tree art already in the game.

## Context / References
- Owner mockup: `docs/visuals/walls/reference-stone-mockup.png`. Use the raised **border blocks and trim pieces** (bottom rows and the border around the big floor: dark slate-blue stone, worn edges, thin gold inlay line, cloud-scroll gold corner ornaments, small gold-capped corner posts). This is the wall language: same slate/gold palette as the floor tiles in `assets/environment/kosen_courtyard/floor_tiles/`.
- Trees for lighting/scale/quality bar: `assets/environment/blossom_trees/`.
- Camera/art direction: `docs/visuals/CAMERA_AND_ART_DIRECTION.md`. Three-quarter view; a standing figure is 108 px tall in world space (camera zoom now 0.75 by default, so art must read at roughly 75% scale).
- Current placeholders: `WorldScale.BLOCKS` (`scripts/world_scale.gd`) drawn by `TrainingArena.Block` / `BlockRear` (front face, east face, roof), plus the World Builder catalog `PlacedObjects.CATALOG` (`scripts/editor/placed_objects.gd`): wall_h 270x90 h150, wall_v 90x270 h150, rock 120x110 h110, crate 108x108 h108. Existing arena walls range 90x520 to 450x90, heights 90 to 162.

## Scope / Files owned
New art only under `assets/environment/kosen_courtyard/walls/` (plus docs/previews under `docs/visuals/walls/`). Do NOT edit `training_arena.gd`, `world_scale.gd`, collision, navigation or the editor; Aki owns those.

## Deliverables
1. A **modular wall kit** that can be tiled to any length and height: left end cap, right end cap, straight middle segment (a few variants to avoid repetition), corner piece, each as the three visible faces for the existing draw model (front face, east face, roof/top cap), with the gold inlay trim and a stone base. Segment widths on a 36 px grid so walls of 90/144/270/450/520 px assemble without scaling.
2. A **rock** (stone outcrop, same palette) and a **crate/stone block** to replace those placeholders, one or two variants each.
3. A manifest `walls.art.json` listing each piece: file, size, ground anchor, footprint it covers (w x depth) and height, so Aki can drive the collision from the same numbers.
4. Contact sheet, an in-game mockup/screenshot at default zoom 0.75, report in `orders/Codex/reports/`.

## Acceptance Criteria / Tests
- Reads as the same world as the floor tiles and trees (palette, outline, lighting direction); no magenta, no baked-in drop shadows that fight the floor.
- Seams between tiled segments are invisible at zoom 0.75 and 1.0; no white rectangles, halos or stray pixels.
- Piece sizes and anchors exactly match the manifest; footprints stay compatible with existing collision (walls 90 deep, heights 90 to 162).
- Godot import clean, existing tests unchanged (art only), Web export builds, report lists exact commands and results.

## Handoff / Notes
When status is REVIEW, Aki will wire the kit into the arena blocks and the World Builder catalog (separate PR) and verify collision/nav, y-sorting behind/in front of the player, and live SHA.
