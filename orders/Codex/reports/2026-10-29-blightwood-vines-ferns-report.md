# Job Report — Blightwood hanging vines and fern clusters
- Agent: Codex
- Order: `orders/Codex/2026-10-29-blightwood-vines-ferns.md`
- Date: 2026-10-29 (America/New_York)
- Final status: DONE — integrated, deployed and verified in the actual browser editor
- Implementation: `a00adeb3e266cbdf859dd542943a4911b0de8de3` / [PR258](https://github.com/kiotdstudios/shinobi-rush/pull/258), merged as `ae03d6ad6e2e647dfc5952673cb6f2c9881e4f30`.
- Sway correction: `64cb9d70120c2f2b6179fd37f6d6b3391a990301` / [PR259](https://github.com/kiotdstudios/shinobi-rush/pull/259), merged as **`aeb5968179b94f15b7f4c72761f1ee0a561d07c1`**.

## Work completed

Created three hanging ivy variations and three small fern clusters through PixelLab MCP using the exact approved grass palette. Transparent native 128×128 sprites, source PNGs/object IDs/hashes, reproducible nearest-neighbor processing and anchor metadata are preserved. No raw art was painted by code. Added native-texel GPU sway with pinned tops/roots, 96 phases at 24 FPS over four seconds. These are shader phases, not 96 individually generated drawings.

Added the Blightwood foliage object category and independent layer, visible-leaf picking, dragging, erasing, undo/redo and exact save/reload. Plants have no physics/navigation bodies. Vines lift 66px to the existing cliff lip and preserve draw order when moved. Six vines and nine ferns dress the riverbank template (1,282 objects; original 134 elevation cells unchanged). Existing maps, grass, waterfall, stairs, camera, movement and combat systems are preserved.

Added actual gameplay/editor screenshots, contact sheet and small normal/half-speed previews showing all six pieces. Normal has 96 frames /4,000ms; half speed has the same 96 frames /8,000ms. Actual rendered pixel validation checks visible movement, fixed nonempty attachment regions and exact palette throughout all 96 phases.

## Files changed

- `assets/environment/blightwood_foliage/`: six production sprites/imports, raw PixelLab provenance and foliage.art.json.
- `scripts/environment/blightwood_foliage.gd`, `shaders/blightwood_foliage.gdshader`: pinned native-pixel sway normalized to each opaque silhouette height.
- `scripts/editor/placed_objects.gd`, `world_editor.gd`: catalog, palette/layers, picking, movement/history, persistence and nonblocking decoration handling.
- `scripts/art/build_blightwood_foliage.py`, `build_river_section.py`: reproducible processing/dressing; both version-5 map copies updated.
- `scripts/art/cliff_kit_review.gd`, `scripts/ci/smoke/foliage-probe.mjs`: optional foliage category and read-only UI observations for real mouse/keyboard browser tests.
- `tests/test_blightwood_foliage.gd`, `tests/run_tests.gd`: 51 new foliage checks.
- `tools/capture_blightwood_foliage.gd`, `scripts/art/validate_foliage_render.py`: actual GPU capture and pixel validation without instantiating gameplay.
- `export_presets.cfg`: raw source art excluded from shipped pack.
- `docs/visuals/vines-ferns/`, river-section README, order/report: previews, usage and durable local/CI/live evidence.

## Tests performed before implementation commits

Windows PowerShell, bundled Python/Node, Godot4.7.2 and Chromium Playwright. Worktree `.tools/ground-mist`; unrelated branches and generated UID sidecars preserved separately. The initial report existed before PR258's implementation commit; the motion-correction section existed before PR259's implementation commit. This final report consolidates that history with post-deployment evidence.

| Exact command / manual steps | Observed result |
| --- | --- |
| `python scripts/art/build_blightwood_foliage.py` | Six valid native transparent sources, sampled palette and fixed anchors |
| `python scripts/art/build_river_section.py` | 1,282 objects /134 cells; fern roots on dry soil |
| `python scripts/art/validate_cliff_kit.py` | 19 modules /16 unique cascade frames /7 original sources unchanged |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script ../cliff-kit-scratch/foliage-focused.gd` | Initial 107 passed; corrected **113 passed /0 failed** (foliage plus modular cliffs/player/bandit stairs). [Durable native results](../../../docs/visuals/vines-ferns/native-result.json) |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/vines-ferns/sway-resources` | Final **445 scripts /30 scenes /2 resources /0 failures** |
| `python scripts/ci/validate_godot_project.py --project . --json-out build/vines-ferns/project-validation.json` | 0 errors /0 warnings |
| `python scripts/ci/validate_orders.py`; `git diff --check` | PASS before implementation and evidence commits |
| `python scripts/ci/godot_ci.py export --project . --out ../vines-ferns-sway-web --log-dir build/vines-ferns/sway-export`; `finalize-export --project . --out ../vines-ferns-sway-web --kind game`; `check-export --dir ../vines-ferns-sway-web --kind game --project .` | Fresh Web export PASS; project.binary, one sprite manifest and 2,378 production PNG imports. Local build-info labels the then-base main SHA, not a deployed uncommitted fix |
| `node scripts/ci/smoke/foliage-probe.mjs --serve-dir ../vines-ferns-sway-web --out-dir build/vines-ferns/sway-gameplay` | 13 actual editor/browser checks PASS, zero errors. [Local evidence](../../../docs/visuals/vines-ferns/gameplay/result.json) |
| `godot --path . --rendering-method gl_compatibility --resolution 768x160 --position=-3000,-3000 --script tools/capture_blightwood_foliage.gd`; `python scripts/art/validate_foliage_render.py` | Actual native GPU (RTX3080 /OpenGL3.3): all six assets visibly move, pinned attachment regions remain fixed, exact palette preserved in all 96 phases. [Rendered result](../../../docs/visuals/vines-ferns/render-validation.json) |
| Visually inspected contact sheet, native rendered poses, actual local editor, canonical editor and waterfall detail | PASS: readable small clusters/attached ivy, clear stairs/waterfall, correct palette/native pixels |

Browser tests use actual cards, mouse/keyboard and Playtest controls; no gameplay-state setters. They cover placement, undo/redo, visible-leaf selection and drag, erase/undo, layer hide/show, file save/reload, edited Playtest and normal saved-world preservation.

## Reviewed integration and deployment

Both PRs used normal expected-head squash merges after all checks passed. No inline review findings remained. Diffs against their integrated main trees were empty. [PR258 checks](../../../docs/visuals/vines-ferns/pr-checks.json) include the full controls, smoke and debug-log regression. [PR259 checks](../../../docs/visuals/vines-ferns/correction-checks.json) confirm **5,186 native assertions passed /0 failed**, Web export/browser smoke and final gate.

Final [main workflow40898248082](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40898248082) succeeded: detection, **5,186 tests /0 failures**, resource validation (445/30/2/0), Web export, pre-deploy smoke, **deploy**, **smoke-postdeploy** and gate. [Deployment checks](../../../docs/visuals/vines-ferns/deployment-checks.json).

Canonical live probe:

`node scripts/ci/smoke/foliage-probe.mjs --url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha aeb5968179b94f15b7f4c72761f1ee0a561d07c1 --out-dir build/vines-ferns/live`

**14 checks PASS, zero browser/engine errors**, completed 2026-10-29T15:26:49.821Z. The build-info SHA exactly matched the integrated commit. Visited the actual game `?cliffs=river&editor=1&foliage=1` and browser editor `?cliffs=river&map_editor=1&foliage=1`; verified all six cards, fifteen authored plants, fixed root coordinates while sway advances, layer visibility, placement, drag, erase/history, exact save/reload and edited Playtest. The normal saved-world key remained unchanged.

[Open live editor](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&foliage=1&v=aeb59681) · [Live editor screenshot](../../../docs/visuals/vines-ferns/live/editor.png) · [Live waterfall](../../../docs/visuals/vines-ferns/live/cliff-detail.png) · [Live results](../../../docs/visuals/vines-ferns/live/result.json).

## Issues encountered and resolved

- The shortest fern (42px) originally had zero rounded movement under the shared72px sway range. A phase-only test missed this. PR259 normalizes range to native opaque height and adds actual rendered-pixel validation across all assets/phases. Resolved before final delivery.
- Fixed review pick-coordinate Variant inference; final resource/browser checks pass. Moved one proposed fern from water onto dry bank (builder rejects wet roots).
- Direct storage download returned403; the normal PixelLab MCP object-download endpoint returned the original PNGs. No credentials were exposed.
- Native QA capture initially inherited the project's viewport stretch; explicitly disabled scaling to capture native pixels. Final renderer/validator passes.
- Corrected report UTF-8 punctuation and export-check flag spelling (`--dir`). Used a fresh output directory for the corrected export. Unrelated generated UID sidecars are archived outside the checkout and excluded.

No remaining known failures or runtime blockers.

## Questions for project owner
None.

## Outstanding work / next steps
Runtime work is complete. This report-only follow-up publishes final deployment evidence and marks the order DONE. **Live deployment: not applicable to this documentation-only follow-up**; the functional runtime above is already integrated, deployed and verified. No additional art or code work is required for this order.
