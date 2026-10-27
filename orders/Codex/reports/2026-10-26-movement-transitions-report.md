# PR 224 — player and bandit traversal transitions

Status: REVIEW. Local implementation complete; PR/main CI and canonical live verification pending. NOT LIVE yet.

## Assignment / scope

Owner explicitly requested execution of PR #224. The original Aki order is retained, with reassignment recorded. Work starts from main `7050d32b` plus the specification commit `bb61c5ee`. Dedicated local branch `codex/movement-transitions`; delivery updates PR #224's existing branch, without replacing other open work.

Both actors receive start, stop and pivot presentation, including run/sprint variants, all eight directions and explicit interruption/fallback behavior. No gameplay speed, acceleration, friction, collision, input buffering, combat or AI state machine changes. Camera unchanged. Tap-L2 substitution / hold-L2 charge unchanged.

## Files / art audit

- Both existing character manifests: six non-looping transition clips each; 3 approved poses × 8 literal headings. 128×128 RGBA; origin `(64,116)`; no rescaling, mirroring, blurred pixels, new equipment or character redesign. Direct source references avoid texture duplication.
- `scripts/sprites/locomotion_transition.gd`: shared visual clock; 100/130/120 ms launch/brake/pivot; 220 ms turn hysteresis; ~90°/180° turns; per-frame directional art; optional missing-art fallback.
- `scripts/player/player_visual.gd` and the traversal call in `player_controller.gd`: physics-clock presentation, immediate gameplay movement, action interruption, post-launch/pivot loop handoff. Missing optional cosmetic actions do not restart launch.
- `scripts/enemy/bandit_visual.gd`: presentation-only wiring; preserves its existing 140 ms AI turn pause, cadence and combat priorities. Evade, attack, hurt and death keep their existing presentation priority.
- `scripts/art/movement_transition_review.gd`, its scene and opt-in proof route: real player and bandit controllers; before/after comparison; normal/half-speed controls; read-only browser telemetry.
- `scripts/art/build_movement_transitions.py`, `preview_movement_transitions.py`, contact sheets, source-path/SHA inventory, normal/half-speed GIFs and integration README.
- Tests: new clock/direction/real-controller regression; existing bandit art fixture waits for transition completion before asserting settled loop; chase verifies launch then sprint; kunai coverage asserts attachment clearing during launch.
- Browser probe records before/after gameplay and checks actual key movement, transition observations, action priority, bandit patrol and console errors.

## Validation log

- Source asset audit: PASS, 2 actors × 6 clips × 8 directions × 3 unique source poses. Source PNGs unchanged; fixed dimensions/anchors verified.
- Initial focused movement/chase/kunai regression: 468 passed / 0 failed.
- Extended focused regression after AI pause and missing-cosmetic fixes: **489 passed / 0 failed**, no engine/script errors (`build/movement-targeted-final.log`). Includes real player motion on the first physics tick at 30/60 Hz, action priority, velocity immutability and real bandit pivot during unchanged turn pause.
- Initial broad preflight was deliberately stopped before completion; not counted as a passing test.
- First complete broad suite: **3564 passed / 24 failed**. All failures were the existing bandit static art fixture asserting immediate idle/run while the new clip was active. Updated fixture explicitly advances 200 ms, preserving exact direction/loop/anchor expectations. No engine/script errors in that run.
- Broad native suite before the final keyboard-corner refinement: **3591 passed / 0 failed**, no engine/script errors (`build/movement-final-tests/tests-builtin.log`).
- Resource walker: **405 scripts, 30 scenes, 2 resources, 0 failures** (`build/movement-final-validation/validate-resources.log`).
- Debug Web export: PASS, pinned Godot 4.7.2, fresh sibling `.tools/movement-transitions-web` (`build/movement-final-export/export.log`). Local build has no commit SHA baked because it precedes the implementation commit; do not mistake it for live proof.
- Final keyboard-corner regression: **491 passed / 0 failed**, no engine/script errors (`build/movement-targeted-corner.log`). Browser input exposed a transient diagonal intermediary; stable-heading tracking now recognizes it as a sharp turn without pivoting under slow steering.
- Final Web re-export after that refinement: PASS (`build/movement-corner-export/export.log`).
- Browser comparison: **12/12 passed**, zero browser/engine errors. Real input moves both comparison modes, attacks interrupt, player start/stop/pivot observed, bandit patrol start/stop observed and patrol keeps moving. Before/after clips and screenshots in `docs/visuals/movement-transitions/gameplay/`. The initial browser run caught the missing corner pivot and is preserved in ignored local logs, not counted as success.
- Normal-map controls smoke test: pending.
- Final pre-commit targeted suite including absent-set placeholder fallback: **492 passed / 0 failed**, no engine/script errors (`build/movement-targeted-commit.log`).
- Final resource walker rerun: **405 scripts / 30 scenes / 2 resources / 0 failures** (`build/movement-commit-validation/validate-resources.log`).
- Order structure and sprite-manifest validation: PASS.
- Preview compositing: normal 4 seconds / half speed 8 seconds, nearest-neighbor source sprites; no raw character art generated procedurally.

## Limitations / integration

Art reuse is intentional and allowed by the brief: these are curated approved poses, not newly drawn custom anatomy. The pivot rotates directional silhouette selection, never the 2D sprite transform. The review scene isolates patrol perception so the two subjects can be compared without combat; normal-game perception is unchanged. Controller input is tested with keyboard equivalents; physical gamepad hardware is not available in this environment.

Do not mark DONE or advertise the canonical deployment until the final tests, reviewed PR integration and exact main SHA/public-browser proof are recorded. Commit SHA and deployment evidence will be added after checks.
