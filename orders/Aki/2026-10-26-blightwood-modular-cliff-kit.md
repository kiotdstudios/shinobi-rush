# Aki Order — Blightwood Modular Cliff Kit + Waterfall Integration

**Status:** DONE — Codex completed the full kit, browser editor integration, reviewed deployment and exact canonical live verification.
**Owner:** Codex (explicit owner reassignment; complete engineering and art scope)
**Priority:** High — first-area world building

## Visual reference on owner's Windows desktop
- `C:\Users\diepowel\Desktop\shinobi_stairs_fix_player_on_top.png`
- `C:\Users\diepowel\Desktop\shinobi_stairs_fix_closeup.png`

The screenshots depict Aki's **existing moss-green capped, dark charcoal stacked-stone retaining wall** and its **integrated three-step staircase**. Treat these as the **primary visual and scale references**: keep the exact stone proportions, staggered cracks/seams, cap colors, lighting, isometric angle, pixel density, and existing stair height. The owner has these screenshots locally; if you cannot access that desktop path, request/obtain the files rather than inventing or claiming to have inspected them. Do not replace this style with generic jagged fantasy cliffs.

## Existing project integration points
- `assets/environment/blightwood/stairs/cliff_ledge_se.png`, `earth_stairs_se.png`, `earth_stairs_sw.png`
- `scripts/editor/placed_objects.gd` — `cliff_ledge_se`, stair catalog definitions, `Landmarks` category, anchors/collision/placement and `link_stair_zones()`
- `scripts/environment/cliff_elevation.gd` — ramp and elevated-landing geometry
- `assets/environment/blightwood_water/waterfall-atlas.png`, `foam-atlas.png`, `droplet.png`, `water.art.json`
- `scripts/environment/blightwood_water.gd` — separately placeable `waterfall_small`, 16-frame cascade at 18 FPS, foam at 13 FPS, droplets; currently fixed offsets (fall (0,-73), foam (0,-1))
- `assets/environment/blightwood_shorelines/` and existing river water tiles
- `scripts/editor/world_editor.gd` — actual map-editor controls and catalog

## Goal
Build a **reusable, modular, snap-together Blightwood cliff kit**, using the EXISTING wall-and-stairs visual language, so the user can paint long walls, corners, turns, elevated platforms, stair entrances, and waterfalls in the live editor. The sample screenshots show a straight wall and stairs; expand that kit, not redesign it. A waterfall should visibly emerge from an upper river, flow over a deliberate opening in the cliff cap, cascade down the vertical stone face, and land in a lower river/basin with foam/spray.

## Required kit pieces
Create a small coherent atlas / modular set (approximately 12–16 base modules, plus directional variants as necessary):
1. Straight wall segments, matching existing moss-capped block courses.
2. Left/right outer corners and left/right inner corners.
3. End caps, wall terminators, and join/transition pieces.
4. Top-cap/upper-ground edge and any needed fill pieces for a continuous elevated surface.
5. Stair-mouth left/right join pieces compatible with BOTH `earth_stairs_se` and `earth_stairs_sw`.
6. Waterfall opening at the top lip, including left/right cap transitions, with water flowing from the upper terrain.
7. Cliff-face waterfall backing/occlusion seam and base-to-water transition as needed.
8. Optional non-animated damp rock/moss details to hide joins without altering gameplay.

Keep native pixel art with transparent backgrounds, exact nearest-neighbor rendering, correct foot anchors and Godot import settings. Specify each module's native dimensions, grid relationship, pivot/anchor, bounds, collider, and intended adjacency. Make directional variants where a mirrored texture would be visibly wrong. Do not stretch or blur existing sprites.

## Critical engineering requirements
- **Do not assume the current waterfall already fits the cliff.** Make a proof-of-fit scene with the existing `waterfall_small` + existing cliff/stairs and upper/lower river before commissioning or regenerating water frames.
- The waterfall uses 128×192 frames and current hard-coded falling-water/foam offsets. Measure the actual wall height, waterfall lip, and basin landing point in world coordinates. If necessary add per-instance offset/height/alignment metadata instead of globally changing every waterfall.
- Preserve independently animated fall, foam, and bounded droplets; avoid visible floating starts, gaps, water passing in front of solid cap stones, or foam landing above the lower river.
- Maintain correct front/back draw order relative to wall top, wall face, player, stairs, and upper/lower ground.
- **Geometry must be real:** cliff walls block lower-level passage; stairs allow traversal to upper level; upper plateau is walkable; no snagging at stair seams. Reuse and extend existing `CliffElevation` / elevation logic rather than building a competing height system.
- Handle upper/lower river placement and collision consistently with the current water behavior; no accidental changes to chakra-water-running.
- Snapping must be deterministic: adjacent modules form continuous caps, faces, corners, and wall seams without one-pixel cracks. Work from the game's actual lattice/coordinate system, not assumptions based only on the screenshot.
- Add kit to the live editor under a clearly named **Blightwood Cliffs** category or a sensible nested Landmarks group; all pieces searchable, with accurate thumbnails and undo/redo, save/load, erase, move, and rotation/variants where supported.
- Existing maps and existing `cliff_ledge_se`/stairs must continue to load. No destructive save schema migration.
- For waterfall variants, ensure the editor exposes placement and any necessary alignment controls. Avoid making one huge pre-rendered waterfall+cliff object as the only option.

## Implementation sequence
1. Audit current cliff/stair/waterfall art and coordinates; inspect both desktop reference PNGs.
2. Build a small **integration proof** with current waterfall and existing wall; document exact seam/offset issues.
3. Produce cliff module art and adjacency/anchor manifest, with contact sheet.
4. Implement editor catalog, preview thumbnails, placement snapping and geometry/elevation integration.
5. Integrate upper river -> lip -> falling water -> lower basin and adjust draw order.
6. Run editor and gameplay tests; deliver screenshots and short animated video.

## Acceptance criteria
- [x] Straight wall can extend 10+ modules without visible gaps.
- [x] Both inside and outside 90-degree turns look seamless.
- [x] Both existing stair orientations attach flush and remain traversable.
- [x] Player and bandit collide with cliff sides correctly; player can walk upstairs, along elevated surface, and back down.
- [x] Waterfall starts at upper river lip, runs over wall face, and visibly hits lower water with foam/spray.
- [x] Animated waterfall does not overlap stone cap incorrectly or float off cliff.
- [x] Works in all supported editor operations: placement, moving, undo/redo, save, reload, erase.
- [x] No regressions to existing shrine elevation, bridges, shoreline auto-tiling, and water animation.
- [x] Native-resolution in-game proof uses the approved committed **wall/stair art** and connected waterfall composition. Desktop screenshots were unavailable and were not inspected; see reference note below.

## Deliverables
- Native transparent pixel assets, source files, contact sheet and placement/adjacency manifest.
- Godot catalog, editor, collision, elevation, and waterfall integration changes.
- A small saved demo layout: long cliff wall, 2 corners, SE+SW stairs, upper/lower river, animated waterfall.
- Before/after editor screenshots and actual gameplay capture.
- Test report with changed files, measured alignment offsets, limitations and any follow-up tasks.

**Definition of done:** a **fully placeable, traversable, reusable modular cliff kit** with working waterfall integration in the actual game editor, not just a sprite sheet or standalone art mockup.

## Active ownership / integration coordination — 2026-10-28
Codex owns this entire implementation on `codex/modular-cliff-system`, based on main `c829538a`. Terrain auto-blending PR245/251 and evidence PR253 are already merged; preserve their floor ownership/retile behavior. Isolate cliff geometry/catalog/river alignment and avoid changing AutoTile/TerrainBlend algorithms. Preserve all legacy ids and layouts. The two named desktop PNGs are absent from available paths; reference-location question sent, committed source cliff/stair art inspected. No claim to have inspected missing files.

## Tested delivery — 2026-10-28
22 editor entries / 19 native module assets; 134-cell demo; both original stair orientations and IDs supported. Full Godot suite: 5,130 passed, zero failures/engine errors. Final browser/editor probe: 26 passed, zero errors. Resource validation: 442 scripts / 30 scenes / 2 resources, zero failures. Native art/source-hash validator passes. See [Codex report](../Codex/reports/2026-10-28-modular-cliff-system-report.md) and [kit instructions/evidence](../../docs/visuals/cliff-kit/README.md). Normal and half-speed runtime videos/GIFs included. Merged [PR254](https://github.com/kiotdstudios/shinobi-rush/pull/254), runtime `8f1f914ce3aa011930b26063508ca76dee461989`. Main deploy/post-deploy smoke/gate passed. Exact canonical live browser/editor probe: 27 passed, zero errors. See the report and live evidence for full verification.
