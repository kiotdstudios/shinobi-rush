# Job Report — Blightwood ground mist
- Agent: Codex
- Order: orders/Codex/2026-10-26-ground-mist.md
- Date: 2026-10-26
- Final status: DONE — reviewed, merged, deployed and verified on canonical live build
- Commit / PR: e968e9f1cb1ccbe7caba04d810f60c7fbc6b0779; https://github.com/kiotdstudios/shinobi-rush/pull/218; live merge 7d01146062116f197b74686d771b5b205e5945d1

## Work completed
Created sixteen original thin, broken sage/blue-grey mist silhouettes. The atlas uses native 128×128 RGBA cells with transparent backgrounds, no floor plate, and nearest sampling. Sources came from built-in image_gen after reviewing the official PixelLab MCP documentation and confirming configured access. No PixelLab generation was claimed or performed.

Added presentation-only GroundMist to the arena: two low ribbons per nearby BlossomTree / DynamicShrine / authored Ancient Shrine shelter, independent 23–34.4 second drift/fade envelopes, subtle native-pixel curling, shared actor Y sorting, peak 20% opacity and an eased clearing around the player down to 8% of that opacity. Fixed 48-sprite pool; source discovery every two seconds; stable slots prevent distance-rank changes from teleporting wisps. Moving, hidden and deleted builder sources are respected. No movement, combat, enemy AI or camera controller was changed.

Fixed the existing controls-probe wall approach fixture with real S input before the original W collision assertions. Kiro handoff records baseline failed workflow 40361150485 / job 121709646372. Added an approach-clearance assertion; original movement and wall-stability thresholds unchanged.

Added `?mist=review` with the real player's WASD movement, Normal / Half / Pause / Mist controls. `?mist=inspect` runs the actual map with read-only counters. Normal gameplay has no browser telemetry. Included contact sheet, full review/world screenshots, actual compositor normal / half-speed GIF crops and reproducible browser checks.

## Files changed
- assets/environment/blightwood_mist/: transparent atlas, import settings, manifest and retained generated source/prompt under .gdignore.
- scripts/environment/ground_mist.gd + .gdshader: bounded source-following presentation and fine curl.
- scenes/main.tscn: independent presentation node only.
- scripts/art/ground_mist_review.gd; scenes/art/ground_mist_review.tscn; kunai_proof_gate.gd: isolated opt-in review route.
- scripts/art/build_ground_mist.py; make_ground_mist_previews.py: deterministic cleanup / preview exports only.
- tests/test_ground_mist.gd; tests/run_tests.gd: source, lifetime, opacity, capacity and readability tests.
- docs/visuals/ground-mist/: art QA, browser proof harness, preview recordings, integration notes and evidence.

## Tests run before commit
Environment: Windows PowerShell; pinned Godot 4.7.2 GL Compatibility; bundled Python / Node; Playwright Chromium. Workspace `.tools/ground-mist`, isolated from the existing dirty `.tools/dynamic-shrine` checkout.

| Command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_ground_mist.py` | 16 unique transparent shapes; no empty or edge-touching cells; shared scale | docs/visuals/ground-mist/asset-qa.json |
| `python scripts/ci/godot_ci.py import --project . --godot <pinned engine> --log-dir build/mist-import` | Pass; source excluded, generated resource sidecars retained | build/mist-import/import.log |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <pinned engine> --log-dir build/mist-resources-final` | 401 scripts / 29 scenes / 0 failures (includes the temporary native focused runner; build/.gdignore now excludes all local tooling from export) | build/mist-resources-final/validate-resources.log |
| `godot --headless --path . --script res://build/test_mist.gd` (deferred focused runner) | 15 passed / 0 failed; no engine errors | terminal / tests/test_ground_mist.gd |
| `python scripts/ci/godot_ci.py tests --project . --godot <pinned engine> --log-dir build/mist-serial-tests` | 3,441 passed / 0 failed; no engine errors | build/mist-serial-tests/tests-builtin.log |
| `python scripts/ci/godot_ci.py export --project . --out ../ground-mist-web-f --godot <pinned engine> --log-dir build/mist-export-f` | Pass; single-threaded debug Web build | build/mist-export-f/export.log |
| `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../ground-mist-web-e --out-dir build/mist-controls-proof` | 36 / 36; real walk, sprint, wall approach/collision, camera lab and vision toggles; 0 runtime errors | docs/visuals/ground-mist/controls-validation.json |
| `node docs/visuals/ground-mist/browser-proof.mjs ../ground-mist-web-f build/mist-shelter-proof` | 14 / 14; real keyboard movement; no console / page errors; actual map discovered 11 sources (10 trees plus the existing Ancient Shrine shelter) and bounded 48 pool | docs/visuals/ground-mist/local-validation.json |
| Paused compositor comparison, Mist on / off | Visible thin source-following ribbons; no full-screen fog; player silhouette stays unobscured; 5,125 changed pixels outside HUD / player | build/mist-on.png, mist-off.png, mist-difference.png |
| `node docs/visuals/ground-mist/record-previews.mjs ../ground-mist-web-d build/mist-recordings` + FFmpeg PNG sampling + `python scripts/art/make_ground_mist_previews.py` | Real 8-second / 16-second captures; GIF excerpts 50 / 100 frames, 4s / 8s, 400×200 native crop, 12.5 FPS, no interpolated frames | docs/visuals/ground-mist/previews.json |
| `python scripts/ci/validate_orders.py`; `git diff --check` | Pass | terminal |

## Issues encountered
Initial pool slots were hidden but retained the default opaque modulation. A bound test caught this; initialize alpha at zero. Focused suite then passed. An early full run had 3,436 passes and this one failure. A second full run reported 3,437 assertions passing but an engine error because the test file was extended while the process retained the prior script without the new set_sources method. That run is explicitly rejected. A later concurrent run hit the existing body-flicker test at line 25 (effect previously freed while manually ticking), aborting that test before cleanup and cascading stale-player failures: 3,297 passed / 39 failed with engine errors. It is rejected. Final serial run used the frozen implementation with no exports or browsers competing and passed all 3,441 assertions without engine errors. First ad-hoc focused runner also needed deferred execution after the SceneTree root entered the tree; corrected before accepting results.

Existing main816f05a6 controls probe had failed before the mist branch: the new starting map leaves the previous movement test already against the north wall (y195.4 →195.0), so its required >20px approach could never pass. The probe now backs away through real input and independently verifies >50px clearance before the original collision test; no gameplay workaround.

Full-map art is intentionally subtle on the high-detail floor; the native-pixel preview excerpt makes the drift easier to inspect on a phone. Physical gamepad and mobile hardware performance have not been measured. Keyboard / Chromium are the exercised platforms.

## Questions for project owner
None.

## Reviewed integration and verified live delivery
PR #218 merged through the normal workflow at 7d01146062116f197b74686d771b5b205e5945d1. Main workflow https://github.com/kiotdstudios/shinobi-rush/actions/runs/40401431454 passed every required job, including pre-deploy, deployment, post-deploy live smoke and godot-ci-gate. Main native result: 3,441 passed / 0 failed; resource validation: 400 scripts / 29 scenes / 0 failures.

`node docs/visuals/ground-mist/browser-proof.mjs https://kiotdstudios.github.io/shinobi-rush/ build/mist-public-proof-7d011` passed 14/14 checks with zero page/console errors at 2026-10-26T21:31:47.178Z. The public build-info SHA was exactly the merged commit. Actual map: 11 discovered tree/shrine sources, 21 visible wisps, fixed 48-slot pool. Screenshots and validation are under docs/visuals/ground-mist/live-proof/; exact CI jobs are in deployment.json.

Live review: https://kiotdstudios.github.io/shinobi-rush/?mist=review&v=7d011460

This follow-up changes only report/evidence files. Before committing it: validate_orders.py, git diff --check and JSON assertions for build SHA, all 14 checks and empty errors passed. No runtime bytes changed.

## Outstanding work / next steps
None for this order. Preexisting primary-checkout and dynamic-shrine QA work was preserved.
