# Job Report â€” Align the Godot project, validator and docs with the locked 128x128 art standard
- Agent: Kiro
- Order: [orders/Kiro/order_01.md](../order_01.md) (follow-up stage 3b: 128x128 alignment)
- Date: 2026-10-18
- Final status: REVIEW (PR open, CI results below; not merged, not deployed from this branch)
- Commit / PR: [PR #8](https://github.com/kiotdstudios/shinobi-rush/pull/8), branch `kiro/order-01-128-standard-alignment`; implementation verified in CI at head ca0b4d33b2d1b4aaf3a923997c5c9e42a88189bb (a later report-only commit adds this line). Live deployment: not applicable until the orchestrator merges (a PR never deploys).

## Work completed
- D2 validator: `scripts/ci/validate_sprite_manifests.py` now errors on a production base `frame_size` other than [128,128] (FRAME128), a per-animation canvas under 128 in either dimension (FRAME128_OVERFLOW), and a `foot_anchor` outside its frame (FOOT_ANCHOR); it warns when `body_height_px` is outside 100-112 (BODY_HEIGHT). Manifests under `references/`, `previews/`, `source/` or `study/` get a schema check only. `export_presets.cfg` exclude_filter keeps those four folders out of the PCK.
- D1/D3/D6 docs and defaults: the 64-vs-128 wording is replaced by the locked rule in the four owned docs; the lab compare mode is described as comparing any two sets; `DEFAULT_BODY_HEIGHT` is 108; lab fallback frame is 128x128; the ruler default is 108; coordination notes (lab zoom vs camera director, WebBridge hooks) are in `GODOT_PROJECT_HANDOFF.md`.
- D4 world scale: new `scripts/world_scale.gd` (factor 2.25 from 108/48) feeds the placeholder figure (108 px), footprint 50x27, tile 144x72, blocks, bounds, speeds and lab stand offsets. All numbers are provisional prototype values for Aki/Orcha to re-tune, not balance.
- D5 performance budget: measured in a temp copy (never committed) and documented in `GODOT_CI_AND_DEPLOYMENT.md` with a pointer in `SPRITE_DROP_IN.md`.

## Files changed
Validator and tests (`scripts/ci/`), `export_presets.cfg`, `scripts/world_scale.gd`, `scripts/sprites/sprite_set.gd`, `scripts/ui/animation_lab.gd`, `scripts/arena/training_arena.gd`, `scripts/player/*`, scenes `player.tscn` and `training_arena.tscn`, `tests/run_tests.gd`, the four owned docs, the earlier Kiro report phrase, this report, and a Status-log line in `order_01.md` (status and checkboxes untouched).

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python -m unittest discover -s scripts/ci/tests` | Ran 131, OK | local, HEAD 324aa0b |
| `python -m unittest scripts.ci.test_validate_sprite_manifests` | Ran 33, OK | local |
| `npm test` in scripts/ci/smoke (node --test) | 23 pass, 0 fail | local |
| `check_workflows.py`, `validate_orders.py`, `validate_godot_project.py --project .` | all rc 0 (PASS, 0 errors, 0 warnings) | local |
| `godot_ci.py import`, `validate-resources`, `tests` (Godot 4.7.2 headless) | rc 0; 12 scripts, 3 scenes validated; SUMMARY: 123 passed, 0 failed | local |
| `godot_ci.py export`, `finalize-export --kind game`, `check-export` | rc 0; export OK 36 MiB; 0 sprite manifests in the PCK | local |
| `smoke.mjs --serve-dir <export> --expected-sha HEAD` (real Chromium, SwiftShader) | VERDICT PASS; start 5083 ms; canvas 1280x720 not blank; input effect 10.3% | local |
| `controls-probe.mjs --serve-dir <export>` | VERDICT PASS; walk dx 157.5 / 500 ms, sprint dx 319.9, wall stops player, 0 console errors | local |
| Screenshots from a temp copy with synthetic sets (placeholder in rescaled arena with ruler and grid; synthetic 128 set; compare mode; 192 overflow set) | opened and checked; saved under c:\tmp\shinobi-order01\stage3\shots, nothing committed | manual |
| D5 perf measurements in a temp copy (real Chromium, SwiftShader) | PCK 8.37 MiB sheets / 10.1 loose / 49.4 noise worst case / 32.1 VRAM-compressed / 0.98 lossy; texture memory 7.1 -> 92.4 MiB, no growth when cycling; 28.4 MiB VRAM-compressed | local; frame rate under software GL is not meaningful |
| GitHub CI on PR #8 at ca0b4d3 ([Godot CI run 39141121856](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39141121856), Repository checks 39141121854, Pipeline self-test 39141121871) | validate-orders-and-project, Detect Godot project, Import/validate/test/export, Pre-deploy smoke, godot-ci-gate, Tooling lint and unit tests, Self-test all pass; Deploy and Post-deploy smoke skipped by design on a PR | downloaded artifacts: build-info.json (kind game, head_sha ca0b4d3, ref refs/pull/8/merge, 9 files hashed), tests-builtin.log 123 passed 0 failed, smoke PASS (engine start 2183 ms, 74 colours, input effect 7.0%), controls probe all ok, screenshot 02-after-input.png opened: rescaled arena with ~108 px placeholder figure |

Local tests were run at 324aa0b; later commits only added the D5 docs, this report and merges of origin/main. Nothing was deployed from this branch.

## Issues encountered
- Finding, pre-existing and not a regression: with the placeholder selected the lab's anim id is empty, so compare mode cannot compare the placeholder against a set in-engine.
- Not verified: visual quality on real art (no real 128x128 art exists yet); phone performance (software GL only).

## Questions for project owner
None

## Outstanding work / next steps
- Orchestrator: verify the live build after merge, then update the order status and boxes.
- Aki/Orcha: re-tune the provisional scaled values.
- Codex: deliver 128x128 sets; consider VRAM compression for Web.
- Camera director (PR #5 order): route lab zoom through it.
