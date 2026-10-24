# Job Report - Blightwood shoreline kit
- Agent: Codex
- Order: orders/Codex/2026-10-24-blightwood-shorelines.md
- Date: 2026-10-24
- Final status: REVIEW - local validation complete; PR/deployment next. NOT LIVE yet.
- Commit / PR: Not committed; report written before implementation commit.

## Work completed
Three PixelLab connected terrain families, 16 pieces each: grass-to-water, dirt-to-water and rocky edges. Native72x36 diamonds use the existing grid and 36,18anchor. Each family supplies four straight banks, four outer corners, four inner corners, two diagonal/split joins and land/water fills. Placement metadata records all corner masks.

Separate native land and water-alpha layers use the already-live water atlas/shared clock/world UV. No generated static water is baked into runtime shore art; static composites are builder thumbnails only. Existing BlightwoodWater renderer adds an optional shore layer while ordinary river/waterfall behavior stays intact. Palettes sampled from live grass, approved ground path, stone floor and river source.

Builder adds independent Grass banks / Dirt banks / Rocky banks filters and48 cards using existing ground painting, selection, movement, deletion and persistence. Read-only telemetry reports shore count and Save access. No map repaint, terrain collision/swimming, combat or camera changes. Interactive shore=review scene has 93connected shore/river cells, normal/half/pause/step and material focus controls. Existing river cells meet each shore's water field.

## Files changed
New assets/environment/blightwood_shorelines (land, masks, thumbnails, metadata and source archives), own review scene/script, browser/native probes, docs/previews and report. Shared water renderer gains an optional land layer; editor catalog and read-only telemetry register the kit; art gate adds opt-in review; test runner includes own coverage. Unrelated ancient shrine report and generated shot_fence_shrine UID remain untouched/uncommitted.

## Tests performed BEFORE commit
- Python docs/visuals/blightwood-shorelines/export_pack.py: PASS 48native tiles,192 corner probes,384 compatible edge-pair configurations, exact land/water alpha union to the existing diamond, native dimensions and placement metadata. Repairs copy only nearest authored land pixels (grass 3, dirt 33, rock 30 pixels across each entire16-piece family).
- Godot 4.7.2 import via scripts/ci/godot_ci.py import --project . --log-dir build/blightwood-shorelines-test-import: PASS. Own import/UID sidecars included.
- Full native suite via scripts/ci/godot_ci.py tests --project . --log-dir build/blightwood-shorelines-tests: 2501PASS,0 FAIL. Coverage includes all 48actual imported layer pairs/catalog IDs, rooted land over advancing shared current, nonblocking placement, move, independent visibility, brush replacement, complete serialization/reload and deleting/freeing layers. Only expected malformed-sheet fixture warning.
- Fresh full-game Web export via export --project . --out ../blightwood-shorelines-final-web-20261024 --log-dir build/blightwood-shorelines-final-export: PASS.
- node scripts/ci/smoke/builder-shorelines-probe.mjs --serve-dir ../blightwood-shorelines-final-web-20261024 --out-dir build/blightwood-shorelines-builder:14/14 checks PASS,0 errors. Three filters,48 cards, Save access, scroll without zoom, place/select/move/delete, hide-cancels, independent filters, all three materials, advancing shared current and save/reload.
- node docs/visuals/blightwood-shorelines/browser-proof.mjs ../blightwood-shorelines-final-web-20261024 build/blightwood-shorelines-review-browser: 12 boolean checks PASS,192 actual captures,0 errors. Rooted shore/current, normal/half/pause/step, individual material focus and All view. Actual assembled scene and focus renders visually inspected: coherent joins and moving clear blue water. Evidence copied to docs.
- GIF packaging verifies192 frames,8000 ms normal /16000 ms half; exact output sizes in preview-validation.json. Order/whitespace checks pass before commit.

## Issues encountered
Initial explicit tile_height request was rejected by PixelLab before generation. Initial top-down angle produced a 1:1 footprint; cancelled those three background jobs and generated the production set at explicit30degree elevation. Tool status text reports72x72storage canvas, but actual delivered production PNGs are native 72x36; PNG dimensions are verified and no source rescaling performed. Direct storage links returned 403; used the service's downloadable ZIP proxy and safe bounded PNG extraction. Early edge validator sampled empty raster tips; restricted edge comparisons to valid diamond samples. Alpha-union validation independently verifies no holes in any tile. These issues are resolved, not waived.

## Questions for project owner
None required. Delivered for visual review; owner approval is not claimed.

## Outstanding work / next steps
Required reviewed PR/CI, main deployment/postdeploy and exact canonical-site visual/builder verification. Final report will record the exact tested SHA/URLs/timestamp. Decorative shoreline visuals do not introduce terrain physics.
