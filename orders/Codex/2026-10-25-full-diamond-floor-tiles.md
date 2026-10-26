# ORDER — Floor tiles must be FULL diamonds (read this first, tell Chief you did)
- Agent: Codex
- Owner: Codex
- Status: QUEUED
- Priority: P0 (direct owner request from Chief)
- Branch/PR: aki/void-seams (Aki already fixed the nine grass tiles; this order is the standard going forward)
- Dependencies: none

## Objective
Chief wants every floor tile made the same way from now on: **a full 72x36 isometric diamond, 100% filled. 1 tile = 1 square.**
No tufts, flowers, props or ragged edges that leave transparent cells inside the diamond. Anything transparent inside the
diamond shows up in the World Builder as a white void between tiles, and Chief spotted it right away.

## Context / References
- Your `grass9_*` tiles (`assets/environment/kosen_courtyard/grass/tiles/`, order `2026-10-22-wind-grass-nine-tiles.md`) were drawn as tufts.
  Measured on 2026-10-25 against the 72x36 lattice diamond: center 54%, edge_nw 47%, edge_se 50%, corner_right 70%, corner_top 67%, the rest 87 to 94%.
  Each tile also sat a different 3 to 13 px too high in its 112x112 canvas, so one anchor could not fix it.
- Aki fixed those nine on 2026-10-25 without repainting: `tools/fix_grass_registration.py` re-registers each tile onto the diamond and fills gaps with the tile's own grass. They are now 100%. Your blades and tufts that overhang the diamond were kept.
- Audit of every other floor tile: `ground9_*`, `shore_grass/dirt/rock_*`, `temple_floor_*` all pass (98 to 100%). Do not redo them. Water shore pieces (`water9_*`) are partial by design.
- The check is automated: `tests/test_floor_coverage.gd` fails any floor tile under 98% diamond coverage. Probe: `tools/probe_tiles.gd`.

## Scope / Files owned
Every new or revised floor-layer tile (ground, grass, path, shore, temple, any future biome floor).

## The standard
1. Canvas for ground-kind tiles is exactly 72x36, or a larger canvas with the diamond centred on the anchor. The diamond (|x|/36 + |y|/18 < 1) is 100% opaque.
2. Decoration (blades, flowers, stones) may overhang OUTSIDE the diamond, never leave holes inside it.
3. Nine-slice roles (corners, edges, center) all share one registration, so they tile with no seams.
4. Night City Props palette, no magenta/pink, no baked props except a feature the tile exists for. Match the warehouse look.
5. Run `tests/test_floor_coverage.gd` before you commit and record the result in your report.

## Deliverables
Acknowledge this order (see Handoff), then follow the standard on all future floor art.

## Acceptance Criteria / Tests
Full test suite passes, including `test_floor_coverage`. No new white void in the World Builder.

## Handoff / Notes
**ACKNOWLEDGE TO CHIEF:** when you pick this up, tell Chief (Diel) in your reply, in plain words: "I read the tiles order." Do not just flip the status; he wants to hear it from you.

A joke so you remember it: why did the grass tile go to therapy? It only ever felt half covered. Do not let your next tile be the one that needs a blanket.

If you ignore this order, the white void gets you.
