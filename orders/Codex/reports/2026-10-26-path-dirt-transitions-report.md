# Job report — existing ground/path to brown dirt
- Agent: Codex
- Date: 2026-10-26 America/New_York
- Order: `orders/Codex/2026-10-26-path-dirt-transitions.md`
- Status: REVIEW — art, builder integration, focused checks, full native regression and actual Web-game review passed. NOT LIVE; scheduled integration pending.
- Branch: `codex/ground-dirt-transitions`
- Commit / PR: Implementation `0739a332c8c2372cc2aee8e28a8464c81d6e3ed6`; https://github.com/kiotdstudios/shinobi-rush/pull/230, depends on PR226. Latest main `46a01f10` (PR225 stair fix) merged without changing its implementation.

## Work completed
Created a companion kit blending the exact existing **Ground / paths** surface into PR226's brown earth. Reused existing pixels and colors, with broken irregular material boundaries, curved corner coverage and three interior variations. No new raw art, grass generation, palette, terrain geometry or map repainting. All floor diamonds are opaque; only the outside of each 72×36 canvas is transparent. Anchor remains `(36,18)`.

The kit has 16 **corner** masks × three variations (48 canonical PNGs) plus nine familiar directional aliases × three (27 PNGs). It uses existing shoreline corner bits: bottom 1, left 2, right 4, top 8; set means dirt. Pure ground and pure earth variants intentionally share their respective pixels. The 42 mixed boundary variations are distinct. Matching corner values maintain material continuity; interior variation vanishes at cell boundaries.

Added **Path to dirt** builder category/filter. Standard floor code provides placement, move, delete, persistence and native picking. No custom controller, camera, collision or AI changes. Optional `?pathdirt=review` demonstrates 121 temporary floor cells inside the actual main game with real movement; it disables autosave and does not change ordinary map loading.

## Files changed
- `assets/environment/blightwood/path_dirt_transitions/`: manifest, 75 native PNGs, lossless imports, usage/mask notes.
- `scripts/art/build_path_dirt_transitions.py`: repeatable compositing from existing ground and earth; contact/tiled sheets.
- `scripts/editor/placed_objects.gd`: 48 catalog records and a category. Existing general floor behavior reused.
- `scripts/art/path_dirt_review.gd`, `kunai_proof_gate.gd`: optional main-game demonstration.
- `tests/test_path_dirt_transitions.gd`, suite registration: imports, full coverage, variation uniqueness, builder filter/place/move/delete/save/load.
- `scripts/ci/smoke/path-dirt-probe.mjs`, screenshots, result JSON and order/report.

## Tests run before commit
Workdir `.tools/ground-mist`. Python: `C:/Users/dielp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`; Node: sibling `dependencies/node/bin/node.exe`. Godot: primary checkout `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

| Command / step | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_path_dirt_transitions.py` | PASS: 48 canonical / 27 aliases, native 72×36, 1296 opaque diamond pixels | assets, manifest, contact sheet, tiled preview |
| `python scripts/ci/godot_ci.py import --project . --godot <pinned> --log-dir build/path-dirt/import` | PASS; lossless nearest-compatible imports/no mipmaps | local log |
| `godot --headless --path . --script res://build/path-dirt/focused.gd` | **211 passed, 0 failed**, no engine errors: floor coverage, new kit and existing ground builder | local `focused.log` |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <pinned> --log-dir build/path-dirt/validate` | PASS: 412 scripts, 30 scenes, 2 resources, zero failures | local log |
| `python scripts/ci/godot_ci.py export --project . --out ../path-dirt-web-20261026 --godot <pinned> --log-dir build/path-dirt/export` | PASS: local debug Web export, unknown SHA explicitly not a deployment | local log |
| `node scripts/ci/smoke/path-dirt-probe.mjs --serve-dir ../path-dirt-web-20261026 --out-dir docs/visuals/path-dirt-transitions/gameplay` | **4/4 PASS**: actual map demo 121 tiles, filter exists, real player crosses blends, no engine/browser errors | actual-game screenshot/movement capture/result JSON; UTC 2026-10-27T03:56:07.001Z |
| `python scripts/ci/godot_ci.py tests --project . --godot <pinned> --log-dir build/path-dirt/tests` | **3763 passed, 0 failed**, no engine errors; only intentional malformed-sprite fixture warning | full local `tests-builtin.log` |
| `python scripts/ci/validate_orders.py`; `git diff --check` | PASS | local output |

## Issues encountered
Initial focused local runner started before the SceneTree root was ready, so scene tests errored despite returning zero assertions failed. Added the initial process-frame wait and reran: 211/0 with no engine errors. No product-code failure hidden or committed. Legacy unrelated regenerated UID files will be preserved in ignored build output, not included in the PR.

## Questions for project owner
None.

## Outstanding work / next steps
PR230 pushed, attached to this task, and explicitly added to the existing one-time 3:40 AM New York open-PR automation; no duplicate automation created. The automation records the current worktree branch and PR226 dependency. **NOT LIVE — required review, integration, main deployment and canonical game verification remain pending.**
