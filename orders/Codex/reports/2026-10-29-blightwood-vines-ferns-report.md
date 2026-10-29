# Job Report — Blightwood hanging vines and fern clusters
- Agent: Codex
- Order: `orders/Codex/2026-10-29-blightwood-vines-ferns.md`
- Date: 2026-10-29 (America/New_York)
- Final status: REVIEW — local acceptance passed; integration/live verification pending
- Commit / PR: Implementation `a00adeb3e266cbdf859dd542943a4911b0de8de3`, [PR258](https://github.com/kiotdstudios/shinobi-rush/pull/258), merged as `ae03d6ad6e2e647dfc5952673cb6f2c9881e4f30`. Original report was written before the implementation commit.

## Work completed

Generated three vine and three fern silhouettes using PixelLab MCP, exact approved grass colors and native transparent 128×128 canvases. Preserved source PNGs, selected object IDs, source hashes and reproducible nearest-neighbor processing. Added gently swaying native-texel shader with pinned roots/top attachments (96 phases, 24 FPS, four seconds; not 96 AI drawings). Added independent editor category/layer, native visible-pixel picking, move/delete/history/save/reload and nonblocking decoration behavior. Added six vines and nine fern clusters around the riverbank starter without changing its 134 elevation cells or existing character/controller/terrain algorithms. Recorded actual Web gameplay/editor screenshots and normal/half-speed previews.

## Files changed

- `assets/environment/blightwood_foliage/`: six sprites, imports, source provenance and anchor/timing manifest.
- `scripts/environment/blightwood_foliage.gd`, `shaders/blightwood_foliage.gdshader`: independent anchored decoration/sway.
- `scripts/editor/placed_objects.gd`, `world_editor.gd`: catalog, filtering/layers, drawing, picking, placement/history and collision exclusions.
- `scripts/art/build_blightwood_foliage.py`, `build_river_section.py`: reproducible processing/map dressing; both river-section JSON copies updated.
- `scripts/art/cliff_kit_review.gd`, `scripts/ci/smoke/foliage-probe.mjs`: optional foliage review/category and read-only observations for actual UI tests.
- `tests/test_blightwood_foliage.gd`, `tests/run_tests.gd`: 45 new assertions.
- `export_presets.cfg`: omit raw source art from shipped pack.
- `docs/visuals/vines-ferns/`, river-section README: evidence, previews and usage.

## Tests run before commit

Environment: Windows PowerShell, bundled Python/Node, Godot 4.7.2, Chromium Playwright software WebGL. Working directory `.tools/ground-mist`; dedicated branch `codex/blightwood-vines-ferns`, base main `37e8f40a19004e24149a85cecd277ac613f3d1ca`.

| Exact command / manual step | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_blightwood_foliage.py` | PASS: six native transparent sources, sampled palette, fixed anchors | contact sheet + manifest/source hashes |
| `python scripts/art/build_river_section.py` | PASS: 1,282 objects /134 cells, fern roots dry | identical runtime/editor map copies |
| `python scripts/art/validate_cliff_kit.py` | PASS: 19 modules, 16 unique cascade frames, seven original sources unchanged | existing cliff validator |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script ../cliff-kit-scratch/foliage-focused.gd` | PASS: 107 assertions /0 failures; includes foliage + modular cliff/player/bandit stairs | `build/vines-ferns/native.log` |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/vines-ferns/resources-final` | PASS: 444 scripts /30 scenes /2 resources /0 failures | resource validation log |
| `python scripts/ci/validate_godot_project.py --project . --json-out build/vines-ferns/project-validation.json` | PASS: 0 errors /0 warnings | JSON |
| `python scripts/ci/validate_orders.py`; `git diff --check` | PASS | console |
| `python scripts/ci/godot_ci.py export --project . --out ../vines-ferns-web --log-dir build/vines-ferns/export`, `finalize-export --project . --out ../vines-ferns-web --kind game`, `check-export --dir ../vines-ferns-web --kind game --project .` | PASS: fresh Web pack, 2,378 sprite PNG imports | export log; local build-info labels base main, not deployed new content |
| `node scripts/ci/smoke/foliage-probe.mjs --serve-dir ../vines-ferns-web --out-dir docs/visuals/vines-ferns/gameplay` | PASS: 13 checks, zero browser/engine errors | gameplay/result.json |
| `node scripts/ci/smoke/cliff-kit-preview.mjs --serve-dir ../vines-ferns-web --query '?cliffs=river&editor=1&foliage=1' --view 6 --out-dir build/vines-ferns/preview` | PASS: real moving waterfall/foliage; FFmpeg timed normal/half-speed exports | capture.json; preview GIF/MP4 |
| Visually inspected actual overview, waterfall detail, editor and contact sheet | PASS: attached ivy, small detailed fern clusters, clear water/stairs, correct palette and native pixels | PNGs in visual folder |

Browser coverage: six distinct catalog assets/fifteen map plants, animated phases with fixed roots, real asset cards, layer hide/show, placement, undo/redo, visible-leaf picking/drag, erase/undo, actual save/reload, edited Playtest, normal saved world preservation, zero errors. No gameplay state setters were used.

## Issues encountered

Fixed a Variant type-inference error in the review-only pick coordinate calculation; final resource validation and browser export pass. Repositioned one proposed fern from water onto dry bank (map builder enforces this). Direct storage download URL returned 403; the normal PixelLab MCP object download endpoint returned the original PNG successfully. Unrelated regenerated UID sidecars are preserved outside the checkout and excluded. No remaining known failures.

## Questions for project owner
None.

## Outstanding work / next steps
Push tested implementation, review PR and CI, integrate via expected-head normal merge, verify main deploy and smoke-postdeploy, then run the actual foliage probe against the exact canonical live revision. Update this report with SHAs, workflow link, live evidence and completion status. Do not claim new foliage is live until then.


## Reviewed integration

All PR checks passed, including normal Godot CI gate, full controls regression, full browser smoke, debug-log regression, repository validation, tooling and pipeline self-test. CI confirms **5,180 native assertions passed /0 failed**, with 444 scripts /30 scenes /2 resources /0 load failures. No inline review findings remained. Normal squash merge used the exact expected head SHA. `git diff --exit-code a00adeb3 origin/main` confirmed identical tested/integrated content immediately after merge.

- [PR Godot CI](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40888371709)
- [Full browser regression](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40888371489)
- [Main deployment workflow](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40891548656) — running; completion/live evidence to follow.
- Durable [PR check summary](../../../docs/visuals/vines-ferns/pr-checks.json) and [focused native results](../../../docs/visuals/vines-ferns/native-result.json).

Report correction: the export-check CLI uses `--dir`, not `--out`. Re-ran that exact check after integration: PASS, project.binary +1 sprite manifest +2,378 sprite PNG imports. This corrects the recorded command spelling; no implementation changed.


## Final motion correction — tested before follow-up implementation commit

Final analysis found the shortest fern (42px opaque height) had zero rounded displacement when using a shared 72px sway span. The earlier phase-only test could not detect this. Corrected sway normalization to each sprite's actual opaque bounds, preserving the roots and whole-texel sampling. Added six native assertions and an actual GPU capture/validation path which checks **rendered pixels**, not just time metadata.

Before this follow-up commit:

- Same focused Godot command: **113 passed /0 failed**, `build/vines-ferns/sway-native.log`.
- `godot --path . --rendering-method gl_compatibility --resolution 768x160 --position=-3000,-3000 --script tools/capture_blightwood_foliage.gd`: PASS, 96 actual GPU phases of all six sprites (NVIDIA RTX3080 /OpenGL3.3). No gameplay scene instantiated.
- `python scripts/art/validate_foliage_render.py`: PASS, all six change actual visible pixels; each nonempty attachment region remains fixed throughout 96 phases; all colors remain in the source palette plus review background. Durable render-validation.json and rendered-poses.png.
- Refreshed normal/half previews using those actual native GPU frames at 24/12 FPS. No source pixels redrawn.
- `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/vines-ferns/sway-resources`: PASS, **445 scripts /30 scenes /2 resources /0 failures**.
- Fresh export to `../vines-ferns-sway-web`, finalized and `check-export --dir ../vines-ferns-sway-web --kind game --project .`: PASS, 2,378 production PNG imports. It labels the base main SHA; local fixes are uncommitted, so this is not a deployed build claim.
- Actual fresh Web editor probe result is recorded below before the follow-up commit.

Intermediate main workflow40891548656 succeeded including deploy/postdeploy for PR258. This is an intermediate revision with the shortest-fern issue described above; final DONE requires the correction's reviewed integration and exact live test.

Questions: None. No controller, movement, terrain, art palette or map layout changes in this correction. Reports also fix UTF-8 punctuation and the export-check command spelling.

Fresh fixed-export browser probe (`node scripts/ci/smoke/foliage-probe.mjs --serve-dir ../vines-ferns-sway-web --out-dir build/vines-ferns/sway-gameplay`): **13 checks passed, zero errors** before follow-up commit. Updated committed gameplay evidence from this run. Orders validation and whitespace checks pass.
