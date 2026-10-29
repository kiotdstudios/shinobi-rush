# Job Report — Blightwood riverbank starter section
- Agent: Codex
- Order: `orders/Codex/2026-10-28-blightwood-river-section.md`
- Date: 2026-10-28 (America/New_York)
- Final status: DONE — merged, deployed and verified on the exact canonical live game/editor.
- Commit / PR: implementation `7e3a9e8644aaf36c9d79f9c5a0bc66130927713f`; [PR256](https://github.com/kiotdstudios/shinobi-rush/pull/256), merged runtime `9bf429cd29ef859918725549b73b325500ef8c6c`. Base was `5aed54122e5b6b3c13e2db99f9d88d9f67c37670`.

## Work completed

Assembled an editable forest riverbank composition from the two user screenshots: 134 connected raised cells, both stair directions, grass-covered banks, upper stream, separate animated lip/cascade/foam/spray, lower catch pool/outflow, winding brown dirt path, trees/rocks/fences/lanterns/fireflies. The saved version-5 map contains 1,267 individually editable objects. No raw artwork was generated or resampled.

Added native wind-animated grass skirts to grass cliff caps. The pieces retain their original ground-plane anchors, collision and save format; vegetation is presentation only and shares existing grass materials. Tall clusters avoid the water outlet. The reference-inspired preset opens the actual browser editor automatically and has a separate saved playtest snapshot/key. It uses the edited map and spawn for Playtest, preserving the ordinary saved world and the original engineering demo.

Inventory and exact decorative gaps are documented in `docs/visuals/river-section/README.md`. This is a reference-inspired usable composition, not a pixel-identical reproduction. Exact banners, small matching fern/bush sprites, hanging cliff vines and the concept's fractured column detail remain art gaps.

## Files changed

- `scripts/art/build_river_section.py`, `world/demos/blightwood-river-section.json`, `assets/environment/blightwood/cliff_kit/river-section.json`: reproducible source/runtime map pair.
- `scripts/environment/cliff_kit.gd`: native shared-wind grass dress on raised grass cells; normal cliff/stair geometry unchanged.
- `scripts/art/cliff_kit_review.gd`: isolated river preset, auto-open editor, distinct snapshot storage and correct edited spawn.
- `scripts/ci/smoke/cliff-kit-probe.mjs`, `cliff-kit-preview.mjs`: reusable river preset/capture options; actual camera zoom drives drag coordinates.
- `tests/test_modular_cliffs.gd`: full item loading, connected topology, animated elevated vegetation, exact save/reload and upper/lower water eligibility checks.
- `docs/visuals/river-section/`: actual browser/editor screenshots, probe result and inventory/instructions.

## Tests performed BEFORE commit

Windows; Godot 4.7.2 stable console; bundled Python/Node; Chromium 1280×720, software WebGL. Local exports contain the tested working-tree changes; their base build-info SHA is not a claim that those changes were deployed.

| Command / check | Result |
| --- | --- |
| `python scripts/art/build_river_section.py` | 1,267 objects / 134 upper cells; source/runtime JSON identical |
| `godot --headless --path . --script ../cliff-kit-scratch/river-focused.gd` | 62 passed / zero failed / no engine errors; `build/river-section/focused-ready.log` |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <4.7.2> --log-dir build/river-section/resources-ready` | 442 scripts / 30 scenes / 2 resources / zero failures |
| `python scripts/ci/godot_ci.py export --project . --godot <4.7.2> --out ../river-section-web-checked --log-dir build/river-section/export-checked` then `finalize-export --kind game` | PASS; actual 56 MiB Web export |
| `node scripts/ci/smoke/cliff-kit-probe.mjs --serve-dir ../river-section-web-checked --preset river --out-dir docs/visuals/river-section/gameplay-final` | 26 passed / zero errors; final evidence moved to `gameplay/` after completion |
| `python scripts/ci/validate_cliff_kit.py` | PASS; 19 native modules, 16 unique cascade frames, all seven original sources unchanged |
| `python scripts/ci/validate_orders.py`; `python scripts/ci/validate_godot_project.py --project .`; `git diff --check` | PASS; static project zero errors/warnings |

Browser verification used real keyboard input and editor controls: both climbs/descents, full-height river/chakra, lower rim collision, waterfall alignment/frame changes, hide/show, catalog placement, undo/redo, drag, erase, file save/reload and actual Playtest popup. The moved edited module appeared in Playtest; the normal saved-world key stayed unchanged. Inspected overview/waterfall/editor screenshots at native browser resolution.

The 62 focused native checks and 26 real-browser acceptance checks passed before commit and cover the changed map, rendering and editor route. The broader normal-timestep rerun completed after the implementation commit: `godot --headless --path . --script res://tests/run_tests.gd` returned zero with **5,135 passed / zero failed / no engine errors**, recorded in `build/river-section/full-normal.log`. No runtime files changed between those checks and integration.

PR CI independently confirmed **5,135 passed / zero failed**, resource validation and Web export. All full browser regression jobs (smoke, controls, debug log), pre-deploy smoke, repository checks and tooling/self-tests passed. Review threads/comments were empty. Normal squash integration used the expected head SHA; `git diff --exit-code 7e3a9e8644aaf36c9d79f9c5a0bc66130927713f origin/main` confirmed an identical tree after merge. No protections/checks were bypassed.

- PR engine/export/pre-deploy gate: https://github.com/kiotdstudios/shinobi-rush/actions/runs/40809014803
- PR comprehensive browser regression: https://github.com/kiotdstudios/shinobi-rush/actions/runs/40809014793
- Main deployment pipeline: https://github.com/kiotdstudios/shinobi-rush/actions/runs/40810490697

## Issues encountered

- First preview had tall grass obscuring the landing splash. Cleared a 145px lower exclusion and suppressed upper tall fringes adjacent to water.
- Initial map import rejected one fence whose broad bounds intersected spawn clearance. Moved it and verified every object loads and survives reload.
- Initial browser steering oscillated around the SE lower waypoint at x≈-300 versus target -288, with elevation already zero. For this heavier river fixture the intermediate lower-mouth tolerance is 18px inside the 72px stair, followed by a separate zero-height/depth assertion. Final 26-check browser run passes. No movement, collision or gameplay timing was changed; native exact physical stair tests remain unchanged.
- First full standard native attempt hit the wrapper's 900s limit while several exports/browser/native checks ran concurrently; no assertion failure was printed before timeout. A fixed-60-FPS experiment completed with four failures in existing real-time bandit-world traversal assertions (5,131 passed / 4 failed). That timing experiment was rejected as validation. The subsequent normal-timestep run passed all 5,135, as did normal CI.
- The prior report-only PR255 had an engine abort during headless import; retrying failed jobs passed, and PR255 merged normally. It contains only the prior cliff delivery evidence.
- Eight unrelated regenerated UID sidecars are preserved outside the final change set.

## Questions for project owner
None required. The remaining decorative art gaps are identified above.

## Outstanding work / next steps
None required for this starter section. Further concept-specific banners, vines, fern/bush and column art are separately identified future decorative work. This completion follow-up changes documentation/evidence only.

## Live deployment
Main pipeline `40810490697` passed engine/resource/export checks, pre-deploy smoke, GitHub Pages deploy, post-deploy live smoke and `godot-ci-gate`. Main CI logs independently confirm **5,135 passed / zero failed**. Repository/tooling/self-test jobs also passed. See `docs/visuals/river-section/deployment-checks.json`.

Ran `node scripts/ci/smoke/cliff-kit-probe.mjs --url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha 9bf429cd29ef859918725549b73b325500ef8c6c --preset river --out-dir build/river-section/live`: **27 passed / zero errors**, completed 2026-10-29T03:32:13.891Z (October 28, America/New_York). The first assertion checked exact deployed SHA; all actual keyboard/editor operations, save/reload and edited-map Playtest were repeated on that revision. Normal saved-world storage remained unchanged.

Inspected canonical live editor screenshot. Evidence: `docs/visuals/river-section/live-result.json`, `live-editor.png`, `live-overview.png`, `native-result.json`, `focused-native.log` and `deployment-checks.json`.

Live editor: https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&v=9bf429cd

Live play: https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&editor=1&v=9bf429cd

Report-only follow-up — **Live deployment: not applicable**. Only documentation/captured evidence changes; runtime delivery above is already deployed and verified. Download keeps an editable JSON; opening the starter link again loads the fresh template. Playtest retains the current edited snapshot under its separate key.
