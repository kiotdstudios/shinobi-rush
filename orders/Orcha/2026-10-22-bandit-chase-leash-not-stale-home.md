# ORDER -- Bandit: chase leash must measure from where THIS chase started, not a stale prior home
- Agent: Orcha
- Status: DONE
- Priority: P0 (bug fix -- the "no home position" order shipped minutes earlier had a second gap)
- Owner: Orcha
- Branch/PR: orcha/bandit-chase-leash-not-stale-home
- Dependencies: orders/Orcha/2026-10-22-bandit-no-home-free-roam.md

## Objective
Owner correction (direct, 2026-10-22, immediately after the "no home position" fix merged): "bandit now
moves to another or second 'home' when ran im towards another part of the map and became undetected he
goes back to the last 'home' area instead of that being his now 'home' area."

Root cause: the chase leash check in `_tick_approach()` (`home.distance_to(global_position) >
chase_leash`) measured distance from the persistent `home` variable -- which only updates on RETURN.
After a Bandit's FIRST disengage moved `home` to area A and it started free-roaming (previous order),
if the player led it into a SECOND chase toward a totally different area B, the leash was still being
measured from stale `home` = A, not from where this NEW chase actually began. Since the Bandit may
already be roaming well beyond `chase_leash` px from A by the time a new chase starts, the leash could
trip almost immediately, forcing it back into RETURN near A again -- exactly "goes back to the last
home area instead of that being his now home area."

## Context / References
- `scripts/enemy/bandit.gd` (`_tick_approach`'s leash check, `_enter()`'s `State.APPROACH` case,
  `home`, now also `_chase_origin`).
- Confirmed via `git grep` that `home` had exactly ONE functional use besides RETURN's snapshot and
  `_ready()`'s init: the leash check. That is the only place that needed to change.

## Scope / Files owned
- `scripts/enemy/bandit.gd`: new `_chase_origin: Vector2` var, set fresh in `_enter()`'s `State.APPROACH`
  case whenever `prev` indicates a genuinely NEW engagement (same condition already used for
  `engagement_count += 1`). `_tick_approach()`'s leash check now reads `_chase_origin`, never `home`.
  `home` itself is untouched -- still only updated on RETURN, still used for nothing else.
- `tests/test_bandit_robber.gd`: `_put()` now also seeds `_chase_origin` to the test's starting
  position (mirroring `set_home`). `_test_leash_and_profile()` updated to drive the leash via
  `_chase_origin` (the mechanism that now actually matters) instead of `set_home()`. New
  `_test_leash_survives_a_stale_prior_home()` proves the exact bug: a stale `home` 1700px away no
  longer forces a give-up, but a stale `_chase_origin` 1700px away correctly still does, and the
  resulting new `home` settles at the real giving-up point, not the old stale value.

## Deliverables
1. `_chase_origin` set to the Bandit's current position every time a fresh engagement begins (APPROACH
   entered from PATROL/NOTICE/IDLE/SEARCH/RETURN). Mid-fight state churn (THREATEN/ATTACK/REPOSITION/
   RETREAT/EVADE/HIT_REACT cycling back to APPROACH) does NOT reset it -- the leash still correctly
   covers the whole fight from when it actually started, not just the latest sub-state.
2. `_tick_approach()`'s leash check: `_chase_origin.distance_to(global_position) > chase_leash`,
   replacing `home.distance_to(...)`.
3. `home` is unaffected: still snapshot on RETURN, still what free-roam settles at and roams around
   (previous order), still irrelevant to the leash now.

## Acceptance Criteria / Tests
- `_test_leash_survives_a_stale_prior_home()`: physically static at a proven-safe anchor the whole
  test (isolates the `home` vs `_chase_origin` distinction from unrelated movement/geometry risk).
  Proves: (a) a fresh engagement sets `_chase_origin` to the current position, not the stale `home`;
  (b) a `home` 1700px away (stale, over the 1500px leash) does NOT stop the chase; (c) once
  `_chase_origin` itself is moved 1700px away (simulating the chase having actually started there),
  the SAME distance correctly triggers RETURN; (d) the resulting `home` settles at the real current
  position, nowhere near the old stale value.
- Full suite: 1334 (prior order) -> 1339/0 (+5 assertions net: 1 new, 4 pre-existing leash assertions
  re-validated against the new mechanism). Zero regressions.
- Real Web export + browser smoke (`controls-probe.mjs`): `VERDICT PASS`, 34/34, 0 console errors.

## Reconciliation Note (added post-rebase)
Aki independently shipped a COMPLEMENTARY fix for a DIFFERENT owner complaint in the same window
(PR #89, ki/chase-leash-fix: 
ot sees_player and home.distance_to(...), owner quote he stops the
chase though I'm in his vision). Both fixes are needed and do not conflict in intent: Aki's gates the
leash on visibility (never give up while the player is in view), mine fixes WHICH point distance is
measured from when the leash is actually allowed to fire. Rebased and merged both conditions into one
line: `if not sees_player and _chase_origin.distance_to(global_position) > chase_leash:`. Full suite
re-verified at 1340/0 after reconciliation (was 1339/0 before Aki's PR landed, +1 from Aki's own new
assertion).

## Handoff / Notes
- This is the SECOND same-day correction to the lock-on/ryo order's "stay in new area" deliverable.
  The first correction (free-roam instead of walking the authored patrol loop) and this one (leash
  measured from the right reference point) are two independent bugs in the same original feature --
  both are now fixed; there is no remaining known gap in this area.
- No new owner questions. This closes the loop the owner flagged.

