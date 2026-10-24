# Job Report -- Bandit: chase leash must measure from where THIS chase started
- Agent: Orcha
- Order: orders/Orcha/2026-10-22-bandit-chase-leash-not-stale-home.md
- Date: 2026-10-22
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Owner caught a SECOND gap in the same lock-on/ryo order's "stay in new area" deliverable, right after
the first correction (free-roam instead of walking the authored patrol loop) merged: "bandit now moves
to another or second 'home' ... he goes back to the last 'home' area instead of that being his now
'home' area."

Root cause: the chase leash (`_tick_approach`'s `home.distance_to(global_position) > chase_leash`)
measured from the persistent `home` variable, which only updates on RETURN. After a first disengage
moved `home` to area A and the Bandit started free-roaming, a second chase toward a new area B would
still measure its leash from stale `home` = A. Since the Bandit may already be roaming well past
`chase_leash` from A by the time it starts a new chase, the leash could trip almost immediately,
snapping it back toward A -- the exact "goes back to the last home" bug reported.

Fix: new `_chase_origin` var, set to the Bandit's current position every time a genuinely fresh
engagement begins (same condition already gating `engagement_count += 1`). The leash check now reads
`_chase_origin`, never `home`. `home` is otherwise untouched.

## Files changed
- `scripts/enemy/bandit.gd`: `_chase_origin` var + doc comment, set in `_enter()`'s `State.APPROACH`
  case, used in `_tick_approach()`'s leash check instead of `home`.
- `tests/test_bandit_robber.gd`: `_put()` seeds `_chase_origin`; `_test_leash_and_profile()` drives the
  leash via `_chase_origin`; new `_test_leash_survives_a_stale_prior_home()`.
- `orders/Orcha/2026-10-22-bandit-chase-leash-not-stale-home.md` (new, this order)

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean, no parse errors |
| `godot_ci.py tests` (full suite) | PASS | `SUMMARY: 1339 passed, 0 failed` (was 1334 before; +5 net: 1 new assertion, 4 pre-existing leash assertions re-validated against the new mechanism) |
| New test specifically | PASS | all 5 `robber leash:` lines confirmed PASS in the log, including the 4 directly proving `_chase_origin` (not `home`) now gates the leash |
| Real Web export + `controls-probe.mjs` (full suite) | PASS | `VERDICT PASS`, 34/34 checks, 0 console errors |

## Issues encountered
Writing the new regression test took several iterations (documented here for anyone touching this test
later): (1) first draft teleported the Bandit to y=1700, outside `WorldScale.ARENA_BOUNDS` (y max
1125), causing unrelated weirdness -- redesigned to stay physically static at the SAME proven-safe
anchor `_test_leash_and_profile` already uses. (2) Player positioned only 50px away triggered an
immediate THREATEN (combat_distance=130) before the leash scenario could run -- moved the player
beyond Level 1's sight_range (500, post Aki's "smaller vision" tune) so `sees_player` stays false.
(3) Setting `last_seen` to the Bandit's own exact position tripped `_tick_approach`'s separate "reached
last seen" give-up path on frame one (arrival check, unrelated to the leash) -- set `last_seen` 300px
away instead so it doesn't instantly "arrive." Final version is deterministic and isolates exactly the
`home` vs `_chase_origin` distinction without conflating it with movement/geometry concerns.

Also caught and fixed (via `git diff` re-review, same recurring `replace_lines` hazard as prior
reports): one edit accidentally deleted `var nav: ArenaNav = null` and another deleted a pre-existing
unrelated assertion (`robber profile: chase is bounded`) -- both restored before running tests; neither
shipped.

No remaining known issues. No regressions in the 1334 pre-existing automated tests.

## Questions for project owner
None -- direct correction of a gap you caught, not a new design decision.

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment, record deployed commit SHA.
