# Job Report -- Proximity "power level" sense while naruto-running (auto-detect + kunai-ready)
- Agent: Orcha
- Order: orders/Orcha/2026-10-22-proximity-sense-naruto-run-kunai-draw.md
- Date: 2026-10-22
- Final status: DONE (pending PR merge + live deploy verification, see below)
- Commit / PR: see follow-up commit note after push

## Work completed
Implemented a new, shared, reusable "proximity sense" mechanic for both the Player and the Bandit,
exactly matching the owner's direct request: while naruto-running (SPRINTing), an actor has an invisible
omnidirectional circle (radius scaled by a new `intelligence` stat: "the higher the stat the bigger the
circle") that auto-detects any enemy inside it and triggers a kunai-ready reaction.

- New `ProximitySense` (RefCounted, pure static functions): `radius_for(intelligence)` (clamped linear
  formula) and `nearest_in_radius(origin, radius, group, tree, exclude)` (distance-only group scan, no
  line-of-sight/cone -- a felt presence, not sight). One shared implementation for both actors.
- PlayerController: new `intelligence` export (default 5), `sensed_enemy`/`kunai_drawn` vars, `sense_radius()`
  helper. Computed fresh every physics frame: cleared at the top of `_physics_process`, only re-populated
  inside the existing plain-SPRINT locomotion branch (so attack/dodge/jump/idle frames always read as "not
  sensing", by design -- you are not passively scanning your surroundings mid-swing). A cosmetic
  `kunai_ready` animation-id overlay call was added using the exact same `play_action`/`has_action`
  fallback contract the existing dodge/jump visuals already use: it is a complete no-op with no visible
  change until Codex adds a "kunai_ready" animation to the production manifest.
- Bandit: new `intelligence` export (default 5), deliberately named and commented as DISTINCT from the
  pre-existing `intelligence_level` (which selects the AI tuning profile and is untouched). New
  `senses_player` bool and `sense_radius()` helper. The check lives inside the existing
  `_update_perception()` (already called every physics frame except DEAD/EVADE/HIT_REACT, matching the
  existing sight-check's lifecycle exactly): gated on the Bandit's own `is_sprinting`, and when sensed
  while in an "unaware" state (PATROL/IDLE/SEARCH/RETURN), fast-tracks into the existing `NOTICE` state --
  no new states, no new animations, reuses the whole existing notice->approach->threaten->attack flow.
- WebBridge: four new published telemetry fields (`player_kunai_drawn`, `player_sense_radius`,
  `bandit_senses_player`, `bandit_sense_radius`) so the mechanic is externally observable/testable in the
  real compiled build, matching the existing `cfx_*`/`bandit_*` telemetry pattern.
- `controls-probe.mjs`: two new smoke assertions reading the new telemetry fields for presence/type/value
  sanity (this is a live-build smoke check, not a behavioral proof -- behavioral proof is the new Godot
  test file, see below).
- `tests/test_proximity_sense.gd` (new, registered in `run_tests.gd`): pure-math radius tests, a
  `nearest_in_radius` group-scan test with a dedicated temp group, a Bandit integration test (real
  `bandit.tscn`, deliberately positioned/faced so the pre-existing cone/`close_sense` vision mechanic is
  structurally excluded, isolating the new mechanic), and a PlayerController integration test (real
  `main.tscn`, teleport-and-measure per phase to eliminate SPRINT_SPEED position drift between checks).

## Files changed
- `scripts/combat/proximity_sense.gd` (new)
- `scripts/player/player_controller.gd` (additive: export, vars, helper, two small hooks in
  `_physics_process`; no existing state/transition/timer logic changed)
- `scripts/enemy/bandit.gd` (additive: export, var, helper, one new branch inside `_update_perception()`)
- `scripts/web/web_bridge.gd` (four new published fields)
- `scripts/ci/smoke/controls-probe.mjs` (two new assertions)
- `tests/test_proximity_sense.gd` (new)
- `tests/run_tests.gd` (registers the new test file)
- `orders/Orcha/2026-10-22-proximity-sense-naruto-run-kunai-draw.md` (new, this order)

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import --project . --godot <godot>` | PASS | `[ DONE ] first_scan_filesystem / update_scripts_classes / loading_editor_layout`, no parse errors |
| `godot_ci.py tests --project . --godot <godot>` (full suite incl. new file) | PASS | `SUMMARY: 1063 passed, 0 failed` (was 1045/0 before this order; +18 new assertions, 0 regressions) |
| `godot_ci.py export --project . --godot <godot> --out <tmp>` (real Web export) | PASS | `[ DONE ] savepack`; produced index.html/js/wasm/pck |
| `node controls-probe.mjs --serve-dir <tmp> --out-dir <tmp-evidence>` (real headless-browser smoke) | PASS | `[probe] VERDICT PASS`; all checks incl. new `player-sense-telemetry` (`player_kunai_drawn=false`, `player_sense_radius=300`) and `bandit-sense-telemetry` (`bandit_senses_player=false`, `bandit_sense_radius=300`); `no-console-errors` 25 messages, 0 error/pageerror |
| Manual trace of two self-caught bugs during editing (see Issues below) | FIXED before commit | re-ran full suite + re-ran local smoke after each fix; both confirmed green |

Formula sanity confirmed from the LIVE compiled build, not just unit math: default `intelligence=5` on
both actors published exactly `220 (BASE_RADIUS) + 5 * 16 (RADIUS_PER_POINT) = 300` px.

## Issues encountered
Two self-inflicted editing mistakes, both caught by diff review and the test suite before commit (not
shipped):
1. An early `replace_lines` edit on `bandit.gd` accidentally deleted the line `q.exclude = excluded`
   inside the EXISTING `line_clear_to()` (wall-occlusion raycast). This would have silently broken the
   Bandit's existing line-of-sight check (the ray would no longer exclude the Bandit's/player's own
   collider). Caught by reviewing `git diff` before running tests; restored immediately; confirmed via
   `git diff` showing a clean, intended-only diff afterward.
2. A `replace_lines` edit on `web_bridge.gd` accidentally dropped the existing `_state.bandit_intent =
   enemy.get_intent()` line while inserting the new telemetry fields nearby. Same catch-and-fix path
   (git diff review before commit).
3. First draft of the Bandit integration test produced two false failures: the test's own player-stand-in
   position (100px away) fell inside the Bandit's PRE-EXISTING `close_sense` (150px) omnidirectional
   sight bypass, so the existing (unrelated) vision mechanic triggered `NOTICE` independently of the new
   code, confounding the assertion. A second failure in the same test was caused by the Bandit's facing
   direction carrying over between sub-tests (the existing `_face()` call during `NOTICE` turns the Bandit
   toward the last-seen player, which then satisfied the existing facing-cone sight check at a FARTHER
   test distance in the next sub-test). Fixed by explicitly resetting `facing8` before each sub-test and
   choosing a test offset (200px, bandit facing perpendicular/away) that structurally excludes the
   pre-existing cone/close_sense mechanic, so each assertion isolates only the new proximity-sense code.
   Re-ran the full suite after the fix: clean pass.

No remaining known issues. No regressions in the 1045 pre-existing automated tests.

## Questions for project owner
1. Should `kunai_drawn`/an enemy entering the Player's sense circle also auto-engage `PlayerLockOn`'s
   manual target (currently L-key-only, "target selection only, does not steer movement/camera/combat")?
   Implemented here as detection + a cosmetic readiness signal ONLY -- not wired into actual combat
   targeting, since that is a combat-feel decision I did not want to assume.
2. Default `intelligence = 5` for both actors (radius 300 px) is a placeholder prototype number with no
   playtesting behind it. Want a different default, or per-level Bandit tuning (e.g. tougher Bandits
   sense farther)?
3. `kunai_ready` has no art yet (Codex's domain). Want this requested as a Codex order, or is the
   detection-only behavior (no visible player pose change yet) acceptable for now?

## Outstanding work / next steps
- Request Codex art for the `kunai_ready` animation id (player) if the owner wants a visible reaction
  beyond the current telemetry-only state.
- Decide (owner, see Q1 above) whether sensing should auto-engage lock-on.
- Push this branch, open/merge the PR through the required CI checks, verify the live deployed build at
  https://kiotdstudios.github.io/shinobi-rush/, and record the deployed commit SHA (follow-up to this
  report once pushed/merged).
