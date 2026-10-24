# ORDER -- Enemy lock-on, sense-circle debug toggle, stay-in-new-area, and ryo-steal targeting
- Agent: Orcha
- Status: DONE
- Priority: P1
- Owner: Orcha
- Branch/PR: orcha/enemy-lock-on-sense-toggle-stay-in-area-ryo
- Dependencies: orders/Orcha/2026-10-22-proximity-sense-naruto-run-kunai-draw.md (ProximitySense, sense_radius(), senses_player)

## Objective
Owner follow-up (direct, 2026-10-22, builds on the proximity-sense order): four requests in one message.
1. "enemies should auto engage lock onto players (later there will be enemies hidden from player view
   and if player runs past them they activate auto engage and try to attack)" -- item 2 (hidden ambush
   enemies) is explicitly deferred by the owner ("later"); only item 1 (auto lock-on) is in scope here.
2. "make sure the intelligence vision have a toggle on and off like the bandit vision" -- a debug
   overlay for the proximity sense circle, mirroring Kiro's existing BanditVisionToggle/Overlay pattern.
3. "bandit currently goes back to his starting location; I want the logic for all enemies to stay in
   their new area" -- RETURN no longer marches the Bandit back to its original spawn.
4. "bandits should be looking for players with ryo; bandit lvl 1 is looking for players with under 30
   ryo to try to steal it upon defeating players; so bandits are in the woods running around looking
   for players (naruto running)" -- a ryo currency stat, a steal-worth-it threshold, and sprinting
   (not walking) between authored patrol waypoints.

Kiro is on vacation until 10/31; this order does not touch `scripts/debug/bandit_vision_*.gd` (his
files), only adds new, separate `scripts/debug/sense_vision_*.gd` files alongside them.

## Context / References
- `scripts/enemy/bandit.gd` (Level 1 Bandit AI), `scripts/player/player_controller.gd`,
  `scripts/combat/proximity_sense.gd` (previous order).
- `scripts/debug/bandit_vision_toggle.gd` / `bandit_vision_overlay.gd` (Kiro's debug overlay pattern,
  mirrored here for the sense circle -- F2 is his key, F1 is DebugHud's; this order uses F3).
- `tests/test_bandit_robber.gd` (Aki's Level 1 robber arena order, 2026-10-21) has two criteria this
  order DELIBERATELY SUPERSEDES per the owner's direct 2026-10-22 instruction (see Handoff/Notes):
  "patrol speed is a walk, not a chase" and "once back on patrol it is near its patrol loop".

## Scope / Files owned
- New: `scripts/debug/sense_vision_toggle.gd`, `scripts/debug/sense_vision_overlay.gd` (F3 toggle +
  overlay for the proximity sense circle; pure-circle rendering, no cone/LOS geometry needed since
  ProximitySense is pure distance).
- New: `tests/test_sense_vision_overlay.gd` (lifecycle: default off, key, button, URL option, no ghost
  nodes, coexistence with BanditVisionToggle, draws one view per live Player/alive-Bandit).
- Touched: `scripts/enemy/bandit.gd` (`locked_target`/`is_locked_on()`, instant-APPROACH on sense,
  `ryo_steal_threshold`/`is_worth_robbing()`/`stolen_ryo`/`_steal_ryo()`, RETURN now settles in place and
  snapshots `home`, PATROL sprints between authored waypoints with `roam_pause`).
- Touched: `scripts/player/player_controller.gd` (`ryo` export, `lose_ryo()`, `ryo_changed` signal).
- Touched: `scripts/ui/animation_lab.gd` (wires `sense_vision` field + button next to the Lab/vision buttons).
- Touched: `scripts/web/web_bridge.gd` (telemetry: `player_ryo`, `bandit_locked_on`, `bandit_stolen_ryo`,
  `sense_vision_on`, `sense_vision_views`, `sense_vision_nodes`).
- Touched: `scripts/ci/smoke/controls-probe.mjs` (F3 toggle smoke checks).
- Touched: `tests/test_bandit_robber.gd` (two superseded assertions updated, see Handoff/Notes),
  `tests/test_proximity_sense.gd` (new lock-on + ryo test functions, sense-fast-track assertion updated
  from NOTICE to APPROACH), `tests/run_tests.gd` (registers the new test file).

## Deliverables
1. Bandit `locked_target: Node2D`, `is_locked_on() -> bool`. The proximity sense now commits straight to
   APPROACH (skipping the sight path's NOTICE suspicion delay) -- "the sense is a felt power-level read,
   not a glimpse that needs confirming."
2. `SenseVisionToggle`/`SenseVisionOverlay`: F3, button left of the Bandit vision button, `?sense_vision=1`
   URL option, `sense_vision_*` telemetry, draws a faint/bright circle (idle/active) per live Player and
   alive Bandit with a label (kind, radius, intelligence).
3. Bandit RETURN snapshots `home = global_position` the instant it is entered (leash exceeded, or SEARCH
   gave up) and only settles briefly (`return_settle_time`) before resuming PATROL -- no walk-back.
4. `PlayerController.ryo` (default 50), `lose_ryo(amount)`. `Bandit.ryo_steal_threshold` (30, distinct
   from `intelligence_level`), `is_worth_robbing(p)`, `stolen_ryo`, `_steal_ryo(p)` wired into `_try_hit`
   on a landed hit (see Handoff/Notes for the "defeating" assumption).
5. Bandit PATROL sprints (`chase_speed`, `is_sprinting = true`) between authored `patrol_points` with a
   short `roam_pause` breather, instead of walking at `profile.patrol_speed` -- this also keeps its own
   proximity sense active while roaming (senses_player requires is_sprinting).

## Acceptance Criteria / Tests
- `is_locked_on()`/`locked_target`: set on APPROACH (sense or sight path), persists through
  THREATEN/ATTACK/etc., clears on PATROL (full disengage) and RETURN (giving up).
- SenseVisionToggle: F3 is unbound elsewhere (key-collision test), default off, button/URL/key all
  toggle it, no ghost node survives OFF or a scene free while ON, coexists cleanly with BanditVisionToggle.
- `is_worth_robbing`: true for a bare stand-in with no `ryo` property (never blocks detection/combat);
  false at/above `ryo_steal_threshold`; true below it. `lose_ryo`: clamps to what is carried, emits
  `ryo_changed`, never negative. `_steal_ryo`: no-op without `lose_ryo()`, steals everything carried and
  tallies `stolen_ryo` otherwise.
- `tests/test_proximity_sense.gd` + `tests/test_sense_vision_overlay.gd` + updated
  `tests/test_bandit_robber.gd`: 1263/0 full suite (was 1211/0 before this order; +52 assertions, 0
  regressions elsewhere).
- Real Web export + browser smoke (`controls-probe.mjs`, both the existing suite and a focused isolated
  F3 check): full PASS. Live telemetry confirmed in the compiled build: `player_ryo=50`,
  `bandit_locked_on=false`, `bandit_stolen_ryo=0`, `bandit_animation="sprint"` while patrolling (confirms
  the naruto-running patrol change is live, not just in headless tests), `sense_vision_on` toggles
  true/false via F3 with exactly 2 views (player + bandit) while on, 0 while off.

## Handoff / Notes
- **Test supersession (flagged, not silent):** owner's 2026-10-22 instructions directly contradict two
  criteria from Aki's 2026-10-21 Level 1 robber arena order: "patrol speed is a walk, not a chase" and
  "once back on patrol it is near its patrol loop." Per the owner's explicit, current direction, both
  assertions were UPDATED (not deleted) in `tests/test_bandit_robber.gd` with comments citing the owner
  quote and the superseded criterion, so Aki can see exactly what changed and why on return from vacation.
- **"Defeating" assumption (needs confirmation):** no player death/HP system exists (locked RPG system,
  not touched here). The steal is wired to a landed hit in `_try_hit` as the closest real combat-
  resolution event available today. If the owner wants a stricter "player death" gate instead, that is a
  new locked-system decision requiring explicit approval, not assumed here.
- **Deferred (owner said "later"):** hidden/ambush enemies that auto-engage when the player runs past
  them undetected. Not implemented. `ProximitySense` is already LOS/wall-independent, so the mechanism
  exists; a future order would only need to spawn such enemies and reuse `senses_player`/`locked_target`
  as-is.
- **Still open (from the previous order's report, unanswered):** should `kunai_drawn`/sensing an enemy
  auto-engage the Player's own `PlayerLockOn` (currently manual, L key)? Not touched -- this message was
  about enemies locking onto players, not the reverse.
- `ryo_steal_threshold` (Bandit, new) and `intelligence_level` (Bandit, existing AI-tuning profile
  selector) are intentionally separate fields; see code comments at both declarations.
