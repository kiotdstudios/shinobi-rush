# Job Report — Chakra-charge runtime integration
- Agent: Codex
- Order: ../2026-10-23-l2-chakra-charge.md
- Date: 2026-10-23
- Final status: REVIEW — waiting for owner input decision
- Commit / PR: Not committed yet; this report precedes runtime implementation commit. PR126 will carry approved body art plus runtime integration. No live deployment claimed yet.

## Work completed
Owner explicitly authorized charge integration. Merged latest origin/main into dedicated art branch without conflicts. Bound approved body art as `charge` in player and enemy-only bandit manifests, all eight headings,16 frames each,6FPS. Added player CHARGE state with planted zero velocity, provisional20chakra/second capped at max, signal-driven HUD refresh, release into locomotion, attack/dodge/jump priority, and damage interruption requiring a release before charging again. No aura or rejected VFX included. Bandit art is reusable through its manifest; no new enemy charging AI invented.

Owner confirmed: preserve substitution on press, add charge on hold. Existing substitution press, buffer, timed hit handling and cooldown code is unchanged. Read the existing substitution action (L2/Q) held duration; after0.30seconds grounded charge begins. Release resets the hold timer. C remains a direct keyboard charge shortcut. No gamepad mapping changes. Bandit manifests expose the shared charge action without inventing new enemy AI behavior.

## Files changed
Player/bandit animation manifests; player_controller.gd; project.godot (charge action keyboard C; L2 mapping unchanged); tests/test_chakra_charge.gd and runner; scripts/ci/smoke/charge-probe.mjs; own order/report. Other checkout's dirty work preserved. Runtime edits are direct-owner-authorized integration scope.

## Tests run before any runtime commit
Windows, bundled Python/Node/Playwright Chromium and Godot4.7.2. Commands from .tools/charge-body-revision; GODOT_BIN points to installed4.7.2console binary.

| Command | Result | Evidence |
| --- | --- | --- |
| Python scripts/ci/validate_sprite_manifests.py | PASS;1 manifest,0 errors | stdout |
| Python scripts/ci/godot_ci.py import --project . --log-dir build/charge-runtime | PASS | import.log |
| Python scripts/ci/godot_ci.py tests --project . --log-dir build/charge-runtime | PASS;2089 passed,0 failed | tests-builtin.log; expected deliberate bad-sheet fixture warning |
| Python scripts/ci/godot_ci.py export --project . --out ../charge-runtime-web --log-dir build/charge-runtime-export | PASS; debug Web export | export.log |
| Node scripts/ci/smoke/charge-probe.mjs ../charge-runtime-web | PASS; real browser C hold enters CHARGE with charge body and hidden weapon; position stays planted; release goes idle, then movement works;0 console/page errors | build/charge-runtime-browser/result.json and charge.png |
| Visual inspection of exported browser screenshot | Body charge visible in actual arena, no aura; existing wide camera retained | charge.png |

## Issues encountered
First export attempted inside project; CI tool rejected it before export. Corrected to sibling directory and export passed. Initial L2 question resolved by owner: existing press stays; add hold only. Physical gamepad unavailable; mapped action and Q-equivalent browser tests executed. Final2092 regression suite covers the hold. Live game not changed at report creation.

## Questions for project owner
None; owner clarified preserve substitution press, add hold charge.

## Final local validation before runtime commit

- Python scripts/ci/godot_ci.py tests --project . --log-dir build/charge-runtime-final: PASS2092,0failed. Includes initial existing substitution window, no charge on short press, sustained L2 action charge, release, chakra cap, movement, dodge/damage interrupt and8-heading art checks for both skins. Existing substitution suite unchanged and passing. Expected deliberate bad-sheet fixture warning only.
- Python scripts/ci/godot_ci.py export --project . --out ../charge-runtime-final-web --log-dir build/charge-runtime-final-export: PASS. Reusing a nonempty export directory was rejected safely; fresh sibling final directory succeeded.
- Node scripts/ci/smoke/charge-probe.mjs ../charge-runtime-final-web: PASS actual Chromium keyboard input through Q (same existing action as L2), short press does not charge; hold shows charge body/no kunai; stable position; release idle then movement;0console/page errors. build/charge-runtime-browser/result.json and charge.png.
- Python scripts/ci/validate_sprite_manifests.py and scripts/ci/validate_orders.py: PASS. git diff --check: PASS.
- Reviewed final diff: existing substitution press/window/cooldown block and project L2 axis binding unchanged. Only hold observation added. Full suite executed before runtime commit. Physical gamepad unavailable; native mapped-action tests and browser Q-equivalent input do not claim hardware testing.

## Outstanding work / next steps

Commit/push tested runtime changes, ready PR126 with updated final scope, check CI, integrate through approved PR process, verify actual Pages deployment and rerun browser hold/release probe against live. Report final SHA/deployment evidence afterward. No VFX added.
