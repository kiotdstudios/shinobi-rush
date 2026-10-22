# P0 — Aki: Fix invisible wall collision / sprite-to-footprint mismatch
- Agent/Owner: Aki
- Priority: P0
- Status: QUEUED
- Date: 2026-10-22

## User bug
User screenshot shows the player apparently hitting a PLACEHOLDER wall while a noticeable visible gap remains. User should not have to guess where an invisible collision starts. Reproduce in the training arena and fix the actual physics/render footprint discrepancy, not by increasing movement speed or disabling collisions.

## Relevant source
- `scripts/arena/training_arena.gd`: `Block extends StaticBody2D` sets rectangle collider `shape.size = footprint`, offset `(0, -size.y/2)`; `Block._draw` paints a vertical front face, while `BlockRear._draw` paints roof and east face as a separately y-sorted sibling.
- `scripts/world_scale.gd`: `BLOCKS` dimensions and placements.
- `scripts/player/player_controller.gd`: CharacterBody2D movement, foot/collision anchor.
- `scripts/arena/arena_nav.gd` (verify actual path): enemy nav and avoidance must stay consistent.
- `scenes/arena/training_arena.tscn` and `scenes/player/player.tscn`.
- User screenshot provided in chat 2026-10-22 shows player near left of long diagonal wall and other PLACEHOLDER blocks.

## Required investigation
1. Reproduce by walking toward each of the long and short blocks from **all eight approach directions**. Record actual world positions, contact normal, player collision shape, and wall collider world-space AABB.
2. Add temporary DEBUG draw toggled in dev builds: wall collision outlines, **actual base footprint**, player collision shape/feet, contact point/normal. Capture screenshot(s) at the moment movement blocks; remove debug by default.
3. Determine whether the apparent gap is from oversized collider, player collider/feet offset, sprite depth projection, `BlockRear` polygon extending beyond collider, collision safe margin, or nav/camera mismatch. In particular, compare the faux-isometric roof/east-face silhouette to the **planar 2D rectangle** collision footprint. Do not assume which is wrong until debug evidence.
4. Align physical blocking to a clearly readable **ground-level footprint**. Players must be able to walk up to the physical base without premature invisible stopping, but must not walk through solid bases. Keep correct y-sorting/occlusion.
5. Keep Bandit pathfinding and player collision consistent with the corrected footprints; no path through solid walls or phantom gaps.

## Acceptance and delivery
- Show before/after collision-overlay evidence for wall in screenshot plus at least two other obstacles.
- Player approaches all sides without a visibly premature stop or clipping; sliding and corner behavior remain stable; Bandit nav unaffected.
- Run Godot import/tests, Web export, actual browser playtest with wall approaches, and record commands/results. Follow `orders/README.md` and `orders/Aki/README.md` mandatory rules.
- Report: `orders/Aki/reports/2026-10-22-wall-collision-visual-gap-report.md` with root cause, changed paths, test evidence, PR and deployed SHA.
- Open dedicated implementation PR; merge after CI/review and deploy to https://kiotdstudios.github.io/shinobi-rush/; **verify the live game yourself**. Do not ask user to inspect code or approve a branch. If blocked, clearly report what prevents deployment.
- Do not change camera, art style, character sprite scale, unrelated combat or Orcha's Body Flicker work.

## Definition of DONE
Actual collision and visible wall base match in live browser, no new navigation regression, and report includes real deployed proof.
