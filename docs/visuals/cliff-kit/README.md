# Blightwood modular cliffs

Native 72×36 diamond cells, one 66-pixel elevation tier. Open the normal map editor and select **Blightwood Cliffs**. The 22 searchable entries include raised stone/grass/path/river surfaces, two-cell straight walls, four outer and four concave inner corners, end caps, stair joins, both staircase orientations, a waterfall lip, and a separately placeable cascade.

Evidence: [contact sheet](contact-sheet.png), [original fit](before-fit.png), [gameplay overview](gameplay/overview.png), [actual editor](gameplay/editor.png), [normal preview](normal.gif), [half-speed preview](half-speed.gif), [normal video](normal.mp4), [half-speed video](half-speed.mp4). GIF previews are 640×480 crops of actual runtime video; the player/waterfall assets are unchanged by preview encoding.

## Build and play

1. Paint connected raised cells. Shared edges disappear automatically; the exposed perimeter becomes the collision boundary. Straight modules can repeat indefinitely. Explicit directional corner variants use the same native cell edges.
2. Attach either SE or SW stairs at a platform edge. Original `earth_stairs_se/sw` IDs also attach when their upper mouths touch a platform. Existing isolated stairs retain their original geometry.
3. Use upper-river cells to lead into a waterfall-lip module. Place **Cliff cascade** near the lip: it snaps to the outlet at module origin + (0,18). Continue with existing lower river tiles underneath the foam.
4. Move, erase, undo/redo, save and reload using the existing editor controls. No map schema migration is required. Overlapping module cells have one visible owner; removing the topmost module reveals the underlying module.

The demo is [world/demos/blightwood-cliff-kit.json](../../../world/demos/blightwood-cliff-kit.json), also packaged under the asset directory for Web exports. It contains 134 raised cells, a long retaining wall, convex/concave corners, both stairs and connected upper/lower water.

Live review routes after deployment:

- `?cliffs=review&editor=1`: actual arena with approach/view buttons; use WASD to climb and descend.
- `?cliffs=review&map_editor=1`: actual browser editor. Select the Blightwood Cliffs category. **Playtest** opens your edited demo.
- `?cliffs=fit&editor=1`: original wall/stair/waterfall alignment proof.

Review saves use separate files and `shinobi-rush:cliff-demo-review:v1`, preserving the normal saved world. These routes are opt-in; ordinary gameplay loads normally.

## Art provenance and measured alignment

The named desktop screenshots were unavailable. A reference-location question was sent; implementation uses the committed approved `cliff_ledge_se.png`, `earth_stairs_se/sw.png`, current ground/grass tiles and existing waterfall frames. We do not claim to have inspected the missing screenshots.

The generated-image experiment was rejected for softened pixels and changed scale; none of its pixels ship. `scripts/art/build_cliff_kit.py` performs native cuts, transparent masks and assembly of existing approved pixels, with no resampling or palette replacement. `cliffs.art.json` records source SHA256 values, anchors, bounds, cell footprints, adjacency and collider metadata. Rebuild with Python/Pillow, then run `scripts/ci/validate_cliff_kit.py`.

The original cliff rise is 66 pixels; the default waterfall has an approximately 150-pixel visible fall and floats when used unchanged here. The original waterfall remains unchanged. The new instance uses 16 native 56×96 crops, anchor (22,74), matching a diagonal upper lip and a 66-pixel drop. In the demo the lip is y=42, basin y=108 and foam y=107. Cascade remains 18 FPS, foam 13 FPS, with 18 bounded droplets. Native stone shoulder layers mask the lip independently. A 9.5-pixel sorting offset changes draw order without moving the rendered water.

## Integration

`CliffWorld` builds connected components and exposed rims from the exact placed cell union. It extends existing `CliffElevation`/`ShrineElevation`, rather than introducing a second actor-height system. Player/bandit navigation uses the same surfaces, stair axes and perimeter. Upper-level visuals receive depth 1; descending restores their original depth. Water eligibility uses the matching modular elevation; foot chakra, splashes and water plants receive presentation offsets while existing chakra rules and frog rarity stay unchanged.

The kit supports one elevation tier matching the approved stairs. It does not stack tiers. Existing maps, legacy IDs, AutoTile/TerrainBlend algorithms, bridge behavior, combat and camera controllers are preserved.

## Reproducible verification

- Native regression: `python scripts/ci/godot_ci.py tests --project . --godot <Godot 4.7.2 console> --log-dir build/cliff-kit/full-tests`
- Resources: same wrapper with `validate-resources`.
- Art: `python scripts/ci/validate_cliff_kit.py`.
- Web: export with `godot_ci.py export`, then `node scripts/ci/smoke/cliff-kit-probe.mjs --serve-dir <export> --out-dir docs/visuals/cliff-kit/gameplay`.
- Live: same browser probe with `--url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha <merged runtime SHA>`.

The Web probe uses actual keyboard input, canvas clicks, catalog selection, drag, undo/redo, erase, file save/reload and the real Playtest button. Its bridge only exposes state and control rectangles. It checks both climbs/descents, upper river/chakra, blocked walls, animated water, edited-map playtest and preservation of normal saves.

Capture video separately with `node scripts/ci/smoke/cliff-kit-preview.mjs --serve-dir <export> --out-dir build/cliff-kit/preview`. It records actual runtime waterfall/foam/droplet motion; `capture.json` identifies the review segment. Recording is separate because software WebGL capture introduces extra input latency. No browser clock overrides or game-input setters are used.

[Twelve repeated straight modules](long-wall.png) form 24 cells with continuous native caps and masonry. Reproduce with `cliff-kit-preview.mjs --serve-dir <export> --layout docs/visuals/cliff-kit/long-wall-layout.json --still 1 --out-dir build/cliff-kit/long-wall`. This loads a separate saved demo through the real runtime; it does not alter normal worlds.
