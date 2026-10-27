# Job report — natural Blightwood dirt path
- Agent: Codex
- Date: 2026-10-26 America/New_York
- Order: `orders/Codex/2026-10-26-natural-dirt-path-revision.md`
- Status: REVIEW — implementation, final art, native regression and actual Web-game comparison passed; required PR integration/deployment pending.
- Commit / PR: Not committed yet; extends https://github.com/kiotdstudios/shinobi-rush/pull/226 on `codex/brown-dirt-path`.

## Work completed
Replaced tile-edge-only brown silhouettes with continuous map-space material blending before cutting diamonds. The existing broad clearing becomes asymmetrical, the authored connecting trails retain their route with rounded and variable-width boundaries. Existing soil/grass art supplies every color and detail. No grass regeneration, terrain geometry, collision, navigation, props, stairs, AI, movement or combat changes.

Runtime presentation applies only at matching authored positions and terrain types. Original IDs/save format remain intact. Other material painting wins, and builder moves restore/reapply appropriate textures. A gated comparison uses the actual main scene with an identical fixed inspection camera; normal gameplay retains its normal camera.

## Files changed
- `scripts/art/build_natural_dirt.py`: deterministic mask/material compositing from existing art and authored map.
- `assets/environment/blightwood/brown_dirt_path/natural-path*`: native atlas, lossless import and cell metadata.
- `scripts/environment/natural_dirt_path.gd`: cached atlas regions and presentation registration.
- `scripts/editor/placed_objects.gd`: floor display/picking/move integration.
- `scripts/art/natural_path_review.gd`, `kunai_proof_gate.gd`: optional actual-map comparison and read-only browser inspection.
- `tests/test_natural_dirt_path.gd`, suite registration: opaque coverage, registration, material/custom-position safety.
- `scripts/ci/smoke/natural-path-probe.mjs`, visual evidence and documentation.

## Tests run before commit
All commands from `.tools/ground-mist`. Python is the bundled runtime `C:/Users/dielp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`; Godot is pinned `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe` from the primary checkout.

| Command / manual step | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_natural_dirt.py` | Final atlas 676 cells, all 317 authored dirt cells; 3584×2464 pixels | generated metadata/layout |
| `python scripts/ci/godot_ci.py import --project . --godot <pinned> --log-dir build/natural-path/import` | PASS; unrelated legacy UID warnings preserved separately | local log |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <pinned> --log-dir build/natural-path/validate` | PASS: 409 scripts, 30 scenes, 2 resources, zero failures | local log |
| `python scripts/ci/godot_ci.py export --project . --out ../natural-path-web-20261026 --godot <pinned> --log-dir build/natural-path/export` | PASS, debug Web export | local log; explicitly local/unknown build SHA |
| `python scripts/ci/godot_ci.py tests --project . --godot <pinned> --log-dir build/natural-path/tests-final` | PASS: **3647 passed, 0 failed**, no script errors | full local log; includes path coverage, floor coverage, map, shoreline move/delete/save/load and movement/combat regressions |
| `godot --headless --path . --script res://build/natural-path/focused.gd` | PASS **131/0**; final color-only adjustment rechecked against floor, brown and natural-path tests; no engine errors | `build/natural-path/focused.log` |
| `python scripts/ci/godot_ci.py export --project . --out ../natural-path-web-final-20261026 --godot <pinned> --log-dir build/natural-path/export-final` | PASS final debug Web export | local log |
| `node scripts/ci/smoke/natural-path-probe.mjs --serve-dir ../natural-path-web-final-20261026 --out-dir docs/visuals/brown-dirt-path/gameplay` | Final PASS: **9/9**; actual main map, both movement checks, identical **3154 object / 103 obstacle** counts, no browser/engine errors | before/after and movement screenshots; result UTC **2026-10-27T03:01:21.386Z** |
| `python scripts/ci/validate_orders.py`; `git diff --check` | PASS | local output |
| Compare diff against main for existing grass/ground PNGs and authored map source | No changes | original grass, ground and map geometry preserved |

## Issues encountered
The first screenshot showed the grass fringe was still too sharp; expanded cluster-scale grass/soil interleaving and reduced the contrast of the broken darker edge band. Initial atlas allocation was increased after the map produced more than 512 affected cells, then cropped to used rows. First full test run found eight map-edge dirt cells omitted by fixed image bounds and a floor refresh cast incorrectly applied to moving water nodes. Derived bounds from the map and limited sprite refresh to actual Sprite2D nodes; the complete rerun passed 3647/0. The final subsequent material-color adjustment passed 131/0 focused checks and the final Web-game comparison.

Existing gray/green ground was main's integrated before state; the rejected rectangular brown illustration was art-only, not previously live. Documented that distinction beside screenshots. Native warnings only concern the suite's intentional malformed-sprite fixture; legacy unrelated UID files regenerated by import are preserved under ignored build output, not committed. This treatment follows the authored map: future authored route changes require regenerating the atlas. Custom material painting is not overwritten.

## Questions for project owner
None.

## Outstanding work / next steps
Commit/push PR226, complete required CI/review/integration, verify main deploy and canonical live game. **NOT LIVE — awaiting reviewed integration.** Local screenshots and local Web verification do not constitute canonical deployment.
