# Job Report -- Enemy lock-on, sense-circle debug toggle, stay-in-new-area, and ryo-steal targeting
- Agent: Orcha
- Order: orders/Orcha/2026-10-22-enemy-lock-on-sense-toggle-stay-in-area-ryo.md
- Date: 2026-10-22
- Final status: DONE (pending PR merge + live deploy verification, see below)
- Commit / PR: see follow-up after push

## Work completed
Four owner requests, all building on the previous proximity-sense order:

1. **Auto lock-on.** `Bandit.locked_target`/`is_locked_on()` added. The proximity sense (already gated on
   `is_sprinting`) now commits straight to APPROACH instead of the slower sight path's NOTICE suspicion
   delay -- a felt power-level read is treated as an instant, confident detection, not a glimpse that
   needs confirming. `locked_target` is set on APPROACH (either path), persists through every actively
   engaged state, and clears on PATROL (full disengage) or RETURN (giving up).
2. **Sense-circle debug toggle.** `SenseVisionToggle`/`SenseVisionOverlay`, mirroring Kiro's
   `BanditVisionToggle`/`BanditVisionOverlay` pattern exactly (same lifecycle, same
   runtime-registered-action approach, same button-row placement) but far simpler: `ProximitySense` is
   pure Euclidean distance with no cone/LOS, so the overlay just draws a circle (dashed+dim while idle,
   solid+bright while actively sensing something) at each live Player/Bandit's `sense_radius()`, with a
   label. Key F3 (F1 is DebugHud's, F2 is Kiro's -- confirmed free via the key-collision scan). Button
   placed left of the Bandit vision button, same row. `?sense_vision=1` URL option. Did not touch any of
   Kiro's `bandit_vision_*` files -- new, separate files only.
3. **Stay in new area.** `Bandit._enter()`'s `State.RETURN` case now snapshots `home = global_position`
   the instant RETURN begins (leash exceeded, or SEARCH gave up), and `_tick_return()` no longer walks
   anywhere -- it just settles (briefly looking around, `return_settle_time`) before resuming PATROL from
   wherever it actually is. The Bandit's patrol loop and future chase leash now shift with it instead of
   snapping back across the map to the original authored spawn.
4. **Ryo-steal targeting.** `PlayerController.ryo` (export, default 50) + `lose_ryo(amount)` (clamped,
   emits `ryo_changed`). `Bandit.ryo_steal_threshold` (export, default 30, deliberately a DIFFERENT field
   from the existing `intelligence_level` AI-tuning selector) + `is_worth_robbing(p)` + `stolen_ryo` +
   `_steal_ryo(p)`, wired into `_try_hit` on a landed hit. Also: Bandit PATROL now sprints (`chase_speed`,
   `is_sprinting = true`) between its authored waypoints with a short `roam_pause` breather, instead of
   walking at `profile.patrol_speed` -- satisfies "naruto running" AND keeps the Bandit's own proximity
   sense active while it patrols (it requires `is_sprinting`), so it is genuinely "running around looking
   for players" now, not just walking a fixed loop.

## Files changed
- New: `scripts/debug/sense_vision_toggle.gd`, `scripts/debug/sense_vision_overlay.gd`,
  `tests/test_sense_vision_overlay.gd`
- `scripts/enemy/bandit.gd`: `ENGAGED_STATES` const, `locked_target`/`stolen_ryo` vars,
  `roam_pause`/`return_settle_time`/`ryo_steal_threshold` exports, `is_locked_on()`/`is_worth_robbing()`/
  `_steal_ryo()` functions, `_enter()`'s APPROACH/RETURN/PATROL cases, `_update_perception()`'s sense
  fast-track (NOTICE -> APPROACH), `_tick_patrol()` (sprint between waypoints), `_tick_return()` (settle
  instead of walk-back), `_try_hit()` (steal hook)
- `scripts/player/player_controller.gd`: `ryo` export, `ryo_changed` signal, `lose_ryo()`
- `scripts/ui/animation_lab.gd`: `sense_vision` field, wired in `_build_ui()`
- `scripts/web/web_bridge.gd`: `player_ryo`, `bandit_locked_on`, `bandit_stolen_ryo`, `sense_vision_on`,
  `sense_vision_views`, `sense_vision_nodes`
- `scripts/ci/smoke/controls-probe.mjs`: `sense-vision-default-off`/`sense-vision-key-toggles-on`/
  `sense-vision-key-toggles-off` checks
- `tests/test_bandit_robber.gd`: two assertions updated (see Issues below), `tests/test_proximity_sense.gd`:
  `test_bandit_lock_on()`, `test_ryo_steal()` added, sense-fast-track assertion updated,
  `tests/run_tests.gd`: registers `test_sense_vision_overlay.gd`
- `orders/Orcha/2026-10-22-enemy-lock-on-sense-toggle-stay-in-area-ryo.md` (new, this order)

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean import, no parse errors across all new/touched files |
| `godot_ci.py tests` (full suite) | PASS | `SUMMARY: 1263 passed, 0 failed` (was 1211/0 before this order; +52 new assertions incl. lock-on, sense toggle lifecycle, ryo steal, updated robber tests; 0 regressions) |
| Real Web export + `controls-probe.mjs` (full existing suite) | PASS | full run before the F3 checks were added confirmed zero regressions in every pre-existing smoke assertion (camera, lab zoom, Bandit vision overlay, proximity sense telemetry); live state showed `bandit_animation: "sprint"` while PATROL (naruto-running patrol confirmed live), `player_ryo: 50`, `bandit_locked_on: false`, `bandit_stolen_ryo: 0`, `sense_vision_on: false` |
| Isolated real-browser F3 toggle check (standalone Playwright script against the same export, after adding the F3 checks to controls-probe.mjs) | PASS | `BEFORE: sense_vision_on=false views=0 nodes=299` -> `AFTER F3: sense_vision_on=true views=2 nodes=300` -> `AFTER F3 again: sense_vision_on=false views=0 nodes=299` -> `RESULT: PASS`. Ran isolated because the full probe's ~3-4 min runtime kept exceeding this environment's per-call timeout ceiling; the isolated check reuses the exact same `visionOpen`-style helpers and confirms the new mechanic works in the real compiled build |

## Issues encountered
1. **Test supersession (intentional, flagged):** two acceptance criteria in Aki's 2026-10-21 Level 1
   robber arena order directly contradict this message's "naruto running" instruction: "patrol speed is
   a walk, not a chase" and "once back on patrol it is near its patrol loop." Both were UPDATED (not
   silently broken) with comments citing the owner's exact words and the specific criterion being
   superseded, so this is visible and traceable, not hidden. Flagged in the order's Handoff/Notes.
2. Several self-inflicted `replace_lines` mistakes during editing (accidentally dropped
   `_notice_blind = 0.0`, a stray `q.exclude = excluded` line, the `_lab_button`/`layer.layer = 5` lines
   in `animation_lab.gd`, the `player_kunai_drawn` telemetry line, and a few duplicate-line artifacts).
   All caught via `git diff` review and a duplicate-adjacent-line scan before running tests; none shipped.
3. First draft of `test_bandit_proximity_sense`'s lock-on assertion failed because the test teleported
   the Bandit without updating its `home`, so the NEW instant-APPROACH behavior immediately tripped the
   pre-existing chase-leash check in the same physics tick (home was still at the default spawn,
   thousands of px away) and transitioned straight to RETURN before the assertion ran. Fixed by calling
   `bandit.set_home(bandit.position)` right after positioning it in the test.
4. The full `controls-probe.mjs` smoke run repeatedly exceeded this environment's per-tool-call timeout
   (observed consistently in the 115-280s range depending on how the call was invoked); worked around by
   running it with output redirected to a file and polling, and by writing a short isolated Playwright
   script for the one new mechanic that needed fresh confirmation after editing the probe file.

No remaining known issues. No regressions in the 1211 pre-existing automated tests.

## Questions for project owner
1. Confirmed assumption: "steal it upon defeating players" is implemented as "upon landing a hit"
   (no player death/HP system exists). Is that acceptable, or do you want a real player-defeat gate
   added first (a locked-system decision)?
2. Still open from the previous report: should sensing an enemy (`kunai_drawn`) auto-engage the Player's
   own `PlayerLockOn` target, or stay manual (L key) as it is today?
3. The two Aki-authored robber-arena criteria superseded by this message's "naruto running" instruction
   are flagged in the order -- confirm this supersession is intended so Aki isn't surprised on return
   from vacation (10/31).
4. Default `ryo_steal_threshold = 30` and `ryo = 50` are placeholder prototype numbers with no
   playtesting. Want different defaults, or per-Bandit-level thresholds later?

## Outstanding work / next steps
- Hidden/ambush enemies (owner: "later") -- not implemented, explicitly deferred. `ProximitySense` is
  already LOS/wall-independent so the groundwork exists; a future order would mainly need to spawn such
  enemies and reuse `senses_player`/`locked_target` as-is.
- Push this branch, open/merge the PR through the required CI checks, verify the live deployed build at
  https://kiotdstudios.github.io/shinobi-rush/, and record the deployed commit SHA (follow-up to this
  report once pushed/merged).
