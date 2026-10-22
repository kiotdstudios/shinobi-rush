# ORDER -- Bandit: no home position, free-roam from last-seen location after a chase
- Agent: Orcha
- Status: DONE
- Priority: P0 (bug fix -- previous order's "stay in new area" deliverable was incomplete)
- Owner: Orcha
- Branch/PR: orcha/bandit-no-home-free-roam
- Dependencies: orders/Orcha/2026-10-22-enemy-lock-on-sense-toggle-stay-in-area-ryo.md

## Objective
Owner correction (direct, 2026-10-22, same day as the lock-on/ryo order): "not alert is sending the
bandit back to his 'home' position i do no want there to be a home position; if bandit chases me, im
undectable for bandit's new 'home' is the last seen location and he continues his search to find
people to attack."

Root cause: the previous order's "stay in new area" fix only updated the `home` VARIABLE (used for the
chase leash check) on RETURN -- it never changed what `_tick_patrol()` actually WALKS TOWARD. PATROL
always targeted the fixed, absolute `patrol_points` array (the level-authored loop anchored at the
ORIGINAL spawn), regardless of where `home` had moved to. So after giving up a chase, the Bandit still
visibly marched back toward the old patrol loop -- exactly the "goes back home" bug the owner is
reporting, even though `home` itself had technically been updated.

## Context / References
- `scripts/enemy/bandit.gd` (`_tick_patrol`, `_enter`'s `State.RETURN`/`State.PATROL` cases, `home`,
  `patrol_points`, `chase_leash` via `_tick_approach`).
- `tests/test_bandit_robber.gd::_test_search_and_return()` already asserted `home` migrates and the
  Bandit sits on it the instant PATROL begins -- that assertion was already true and stayed true; the
  gap was no test exercised what happens a few seconds INTO that PATROL.

## Scope / Files owned
- `scripts/enemy/bandit.gd`: new `_ever_disengaged: bool` (permanently true once RETURN has ever been
  entered), new `roam_radius` export, new `_tick_roam()`/`_pick_roam_target()` functions, `_tick_patrol()`
  branches into `_tick_roam()` when `_ever_disengaged` is true instead of walking the authored loop.
- `tests/test_bandit_robber.gd`: extends `_test_search_and_return()` with assertions that the Bandit
  never approaches the original authored patrol loop again and free-roams near the settle point instead.

## Deliverables
1. `Bandit._ever_disengaged`: set true in `_enter()`'s `State.RETURN` case (alongside the existing
   `home = global_position` snapshot). Permanent for the Bandit's lifetime -- once it has ever given up
   a chase, it never returns to scripted patrol again.
2. `_tick_patrol()`: if `_ever_disengaged` is true, delegates to `_tick_roam()` instead of indexing into
   `patrol_points`. The Bandit's FIRST patrol ever (fresh spawn, never chased anyone) still walks the
   authored loop, preserving the level-designed look of an undisturbed guard.
3. `_tick_roam()`/`_pick_roam_target()`: picks a random point within `roam_radius` (export, default 260
   px, matches the authored loop's scale) of the Bandit's CURRENT position -- not `home`, not the
   original spawn, not any fixed point -- validated against `nav.is_walkable()` with a few retries,
   sprints to it (`is_sprinting = true`, keeps the proximity sense active per the previous order), short
   `roam_pause` breather on arrival, then picks a new one. Continues indefinitely, "looking for people to
   attack" exactly as instructed.
4. `patrol_points`/`chase_leash`/`home` are otherwise untouched: the leash check in `_tick_approach`
   (`home.distance_to(global_position) > chase_leash`) still works correctly since `home` is still
   updated on every RETURN -- it was never the leash logic that was broken, only the PATROL destination.

## Acceptance Criteria / Tests
- `tests/test_bandit_robber.gd::_test_search_and_return()`: after RETURN settles and PATROL resumes,
  over 3 seconds (180 physics frames) of real-arena simulation, the Bandit (a) never gets within 150px
  of the original `WorldScale.BANDIT_HOME`, (b) sprints at least once, (c) stays within
  `roam_radius * 2.5` of the settle point (bounded roam, not a beeline anywhere), (d) `_ever_disengaged`
  reads true.
- Full suite: 1211 (session start) -> 1331/0 (this fix's own +3 assertions on top of the lock-on/ryo
  order's +120). Zero regressions.
- Real Web export + browser smoke (`controls-probe.mjs`): full `VERDICT PASS`, 34/34 checks, 0 console
  errors. (This fix is pure AI-state logic with no new telemetry/UI surface, so the existing smoke suite
  is the correct regression gate -- no new checks were needed.)

## Handoff / Notes
- This is a direct bug-fix follow-up to the SAME-DAY lock-on/ryo order (PR #82) -- not a new feature.
  No new owner questions raised; this closes the gap flagged implicitly by the owner's correction.
- `patrol_points` remains meaningful only for a Bandit's very first, never-interrupted patrol. Once any
  chase has ever happened, the authored loop is permanently retired for that Bandit instance (matches
  the owner's literal words: "I do not want there to be a home position" -- not "move the home",
  eliminate it as a return destination entirely).
- `roam_radius` (260px) is a provisional prototype value, same tier as `ryo`/`ryo_steal_threshold` from
  the same day's order -- not balanced/playtested.
