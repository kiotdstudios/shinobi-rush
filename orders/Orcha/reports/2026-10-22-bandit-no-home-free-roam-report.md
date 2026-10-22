# Job Report -- Bandit: no home position, free-roam from last-seen location after a chase
- Agent: Orcha
- Order: orders/Orcha/2026-10-22-bandit-no-home-free-roam.md
- Date: 2026-10-22
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Owner caught a real gap in the same-day lock-on/ryo order (PR #82, already merged): "stay in their new
area" only updated the `home` variable (used by the chase-leash check), not what PATROL actually walks
toward. `_tick_patrol()` still indexed into the fixed, absolute `patrol_points` array -- the authored
loop anchored at the ORIGINAL spawn -- so the Bandit visibly marched back toward it after any chase,
regardless of where `home` had moved. That is exactly "not alert is sending the bandit back to his
'home' position."

Fix: `_ever_disengaged` (set true the first time RETURN is ever entered, permanent for that Bandit's
life) now gates `_tick_patrol()`. Once true, `_tick_patrol()` delegates to a new `_tick_roam()`, which
picks random nearby points (within `roam_radius`, validated against `nav.is_walkable()`) relative to the
Bandit's CURRENT position every cycle and sprints between them indefinitely -- never the authored loop,
never any fixed point. A Bandit's very first patrol (before it has ever chased anyone) is unaffected and
still walks the authored loop, preserving the level-designed look of an undisturbed guard.

## Files changed
- `scripts/enemy/bandit.gd`: `_ever_disengaged` var, `roam_radius` export, `_tick_roam()`/
  `_pick_roam_target()` functions, `_tick_patrol()` branch, `_enter()`'s `State.RETURN` case sets
  `_ever_disengaged = true`.
- `tests/test_bandit_robber.gd`: `_test_search_and_return()` extended with 3 new assertions covering the
  specific bug (never approaches the old loop, roams bounded near the settle point, `_ever_disengaged`
  is permanently true).
- `orders/Orcha/2026-10-22-bandit-no-home-free-roam.md` (new, this order)

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean, no parse errors |
| `godot_ci.py tests` (full suite) | PASS | `SUMMARY: 1331 passed, 0 failed` (was 1328 before this fix's own 3 new assertions; 0 regressions) |
| New assertions specifically | PASS | `robber search: never walks back toward the original authored patrol loop once settled`, `robber search: free-roams near the new settle point (bounded by roam_radius), not standing frozen`, `robber search: _ever_disengaged is permanently set after the first RETURN` -- all confirmed PASS in the log |
| Real Web export + `controls-probe.mjs` (full existing suite) | PASS | `VERDICT PASS`, 34/34 checks, 0 console errors. Pure AI-state logic change with no new telemetry/UI, so the existing suite is the correct gate; no new browser checks were needed |

## Issues encountered
Several self-inflicted `replace_lines` duplicate/dropped-line mistakes while editing the `_enter()`
match block and `_tick_patrol()` (dropped `_notice_blind = 0.0`, dropped `_log("says: ...")`/`taunt_timer`/
`engagement_count += 1` lines, duplicated blocks). All caught via `git diff` review and fixed before
running tests; none shipped. This is the same recurring tool-editing hazard noted in prior reports --
every multi-line match-block edit in this file now gets a full `git diff` re-read before trusting it.

No remaining known issues. No regressions in the 1328 pre-existing automated tests.

## Questions for project owner
None -- this is a direct correction of a gap you caught in the same-day lock-on/ryo order, not a new
design decision.

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment, record deployed commit SHA.
