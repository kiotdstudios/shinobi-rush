# ORDER -- Proximity "power level" sense while naruto-running (auto-detect + kunai-ready)
- Agent: Orcha
- Status: DONE
- Priority: P1
- Owner: Orcha
- Branch/PR: orcha/proximity-sense-naruto-run-kunai-draw
- Dependencies: none

## Objective
Owner request (direct, 2026-10-22): "player and bandit need to have the logic when naruto running and
near enemy (near enemy means they can sense enemy power levels around them using their intelligence
stat; lets make it an invisible circle around the player; the higher the stat the bigger the circle;
enemies in that circle player will auto detect and pull their kunai out".

Give both the Player and the Bandit an omnidirectional, invisible "power level" proximity sense, active
only while the actor is naruto-running (SPRINTing), that auto-detects a nearby enemy and triggers a
kunai-ready reaction. Radius scales with a new `intelligence` stat ("the higher the stat the bigger the
circle"). Symmetric capability on both actor types, per the owner's explicit "player and bandit" phrasing.

## Context / References
- `scripts/player/player_controller.gd` (SPRINT state, combat state machine -- Aki's primary domain;
  touched here only additively, no new states, no change to existing transitions/timers).
- `scripts/enemy/bandit.gd` (Level 1 Bandit AI, `_update_perception()`, existing `intelligence_level`
  AI-tuning field -- NOT the same as the new `intelligence` sense stat, see code comments).
- Existing cone/LOS vision (`can_see`, `sight_range`, `fov_deg`, `close_sense`) is untouched; the new
  sense is a deliberately different mechanic (distance-only, no facing cone, no wall occlusion -- a felt
  presence/power-level read, not sight).
- `docs/GAME_DESIGN_DOCUMENT.md` has no existing "intelligence" stat or sense-circle mechanic; no locked
  RPG progression/stat system exists today, so this is introduced as a fresh, tunable prototype stat, not
  a change to any locked persistent-progression rule.

## Scope / Files owned
- New: `scripts/combat/proximity_sense.gd` (ProximitySense -- pure radius formula + group-scan helper,
  shared by both actors so the formula/logic live in exactly one place).
- New: `tests/test_proximity_sense.gd` (pure-math + Bandit + PlayerController integration coverage).
- Touched: `scripts/player/player_controller.gd` (new `intelligence` export, `sensed_enemy`/`kunai_drawn`
  vars, `sense_radius()`, sense computed only in the plain-SPRINT locomotion branch, cosmetic
  `kunai_ready` visual overlay call that falls back silently with no art yet).
- Touched: `scripts/enemy/bandit.gd` (new `intelligence` export distinct from `intelligence_level`,
  `senses_player` var, `sense_radius()`, proximity check added inside the existing `_update_perception()`
  that fast-tracks PATROL/IDLE/SEARCH/RETURN into the existing NOTICE state when sensed).
- Touched: `scripts/web/web_bridge.gd` (telemetry: `player_kunai_drawn`, `player_sense_radius`,
  `bandit_senses_player`, `bandit_sense_radius`).
- Touched: `scripts/ci/smoke/controls-probe.mjs` (two new smoke assertions reading the new telemetry).
- Touched: `tests/run_tests.gd` (registers the new test file).

## Deliverables
1. `ProximitySense.radius_for(intelligence)`: clamped linear radius formula, `BASE_RADIUS`..`MAX_RADIUS`.
2. `ProximitySense.nearest_in_radius(...)`: distance-only nearest-in-group scan, no LOS/cone.
3. Player: `intelligence` stat (default 5), `sense_radius()`, `sensed_enemy`/`kunai_drawn`, computed fresh
   every physics frame (cleared outside SPRINT, re-populated only while actually SPRINTing), cosmetic
   `kunai_ready` animation-id overlay call (silently falls back to the normal sprint pose with no art yet).
4. Bandit: `intelligence` stat (default 5, distinct from `intelligence_level`), `sense_radius()`,
   `senses_player`, gated on the Bandit's own `is_sprinting`; when sensed while PATROL/IDLE/SEARCH/RETURN,
   fast-tracks into the existing `NOTICE` state (reuses the existing notice->approach->threaten flow,
   no new animation/state required).
5. WebBridge telemetry for both, so the mechanic is externally verifiable in the live build.

## Acceptance Criteria / Tests
- `ProximitySense.radius_for`: monotonic in `intelligence`, clamps negative input to `BASE_RADIUS` and
  huge input to `MAX_RADIUS`.
- Player: walking (not sprinting) near an enemy never sets `kunai_drawn`; sprinting near one does;
  sprinting past `sense_radius()` clears it; releasing sprint clears it on the next frame even if the
  enemy never moved.
- Bandit: not naruto-running (`is_sprinting == false`) near the player never sets `senses_player`, even
  inside the circle; naruto-running + in-radius + an unaware state (PATROL) sets `senses_player` and
  enters `NOTICE`; naruto-running but beyond `sense_radius()` does neither. Verified with the bandit
  facing away from, and the player outside, the existing cone/`close_sense` vision range, so the
  assertions isolate the NEW mechanic from the pre-existing, unrelated sight-cone mechanic.
- `tests/test_proximity_sense.gd`: 1063/0 full suite (was 1045/0 before this order; +18 new assertions).
- Local Web export + `controls-probe.mjs` smoke run against it: full probe PASS, including the two new
  `player-sense-telemetry` / `bandit-sense-telemetry` checks, zero console/pageerror. Live values observed:
  `player_kunai_drawn=false`, `player_sense_radius=300`, `bandit_senses_player=false`,
  `bandit_sense_radius=300` (both at default intelligence=5: 220 + 5*16 = 300, formula confirmed correct
  in the actual compiled browser build).

## Handoff / Notes
- `kunai_ready` is a cosmetic animation id with no authored art yet (Codex owns art). The hook is wired
  exactly like the existing dodge/jump pattern (`PlayerVisual.play_action`/`has_action`): it is a complete
  no-op until Codex adds a "kunai_ready" animation to the production sprite manifest, at which point it
  starts showing automatically with zero further code changes.
- Not implemented (explicitly out of scope, flagged for owner decision): auto-engaging `PlayerLockOn`'s
  target when `kunai_drawn` becomes true. `PlayerLockOn` is currently manual-only (L key) by design
  ("Target selection only" -- does not steer movement/camera/combat). Wiring auto-detect into auto-lock-on
  is a combat-feel decision, not assumed here.
- `intelligence_level` (Bandit AI-difficulty tuning, existing) and `intelligence` (new sense stat, this
  order) are intentionally separate fields -- see code comments at both declarations to prevent confusion.
- Both `intelligence` stats are PROVISIONAL PROTOTYPE exports (default 5 for both actors), not balance.
