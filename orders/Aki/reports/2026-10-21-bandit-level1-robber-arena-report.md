# Job Report — Level 1 Bandit robber AI, ninja locomotion, arena walls and distant spawn
- Agent: Aki
- Order: `orders/Aki/2026-10-21-bandit-level1-robber-arena.md` (PR #64 text)
- Date: 2026-10-21
- Final status: REVIEW until the live build is verified (see "Live deployment" at the bottom, updated after deploy)
- Commit / PR: filled in after push (see bottom)

## Work completed
- **Arena**: player spawn unchanged (0,135). The Bandit now lives far east at (1300,-130) (about 1300 px from spawn) and patrols a 4-point loop. Four placeholder blockers added to `WorldScale.BLOCKS` (indexes 5-8): two long walls at x=900 leaving a 280 px choke at y -80..200 with open routes north (above y -600) and south (below y 740), and two rocks (one covering the choke's east mouth, one in the patrol area) that break line of sight. They are real colliders and get the existing Block/BlockRear y-sorting.
- **Navigation** (`scripts/enemy/arena_nav.gd`): AStarGrid2D over the arena (45 px cells, 42 px clearance around blocks and the perimeter), string-pulled paths, synchronous and deterministic (no NavigationServer).
- **Intelligence profile** (`scripts/enemy/enemy_intelligence.gd`): `intelligence_level = 1` exported on the Bandit; every feel number (sight range 700, 110 degree cone, 150 px close sense, 0.65 s notice, 1.6x slower re-acquisition, 2.2 s to lose sight, 1500 px chase leash, attack windup 0.42 s, 40% overcommit, 25% retreat, etc.) lives in one dictionary row. Unknown levels clamp to the highest defined row, so Level 2 is a new row.
- **State machine** (`scripts/enemy/bandit.gd`): PATROL, NOTICE, APPROACH, THREATEN, ATTACK, REPOSITION, RETREAT, SEARCH, RETURN (plus the existing HIT_REACT, DEAD, EVADE, IDLE). Detection needs range + facing cone (except chase states) + a physics ray with no wall in between. It paths around walls, stops to turn on big direction changes, looks around when waiting, patrols at walk speed with the run cycle at a matching cadence.
- **Robber identity**: "Hand over your ryo!" speech box (drawn, never pauses anything) on the first close encounter of each engagement; limited chase (leash and lose-sight timers); investigates last seen, then returns to patrol. No currency or economy.
- **Attacks**: two-swing combo with a 0.42 s red tell (arc fills as it nears), aim tracks only through the first half of the tell and then freezes, lunge during active frames, hit needs reach + arc + a clear line (no hits through walls). 40% overcommit: swing 2 lunges on a frozen aim and ends in 0.85 s recovery. 2.2 s cooldown.
- **Rare double backward Body Flicker**: 25% after a non-overcommitted combo. 0.35 s telegraph, hop (up to 230 px, shortened or skipped if a wall is behind it), 0.16 s pause, second hop, 0.7 s recovery. Invulnerable only while hopping. It is never triggered on the player's side.
- **Player hit hook** (`PlayerController.take_hit`): counts the hit, tints, small shove, 0.45 s grace. Dodge, jump and air attack evade it. There is no player HP or death (locked rules untouched).
- **Observability**: label reads `BANDIT L1 (STATE)`; `window.__SHINOBI_STATE__` gains `bandit_level/intent/sees/flickers/swings/hits_landed/stuck/taunt/home_dist/log` and `player_hits_taken`; the Bandit keeps an `intent_log` ring buffer.

## Files changed
New: `scripts/enemy/arena_nav.gd`, `scripts/enemy/enemy_intelligence.gd` (+ .uid), `tests/test_bandit_robber.gd`, `orders/Codex/2026-10-21-bandit-level1-action-art.md`. Rewritten: `scripts/enemy/bandit.gd`, `scripts/ci/smoke/bandit-probe.mjs`. Edited: `scripts/enemy/bandit_visual.gd`, `scripts/arena/training_arena.gd`, `scripts/world_scale.gd`, `scripts/player/player_controller.gd`, `scripts/web/web_bridge.gd`, `tests/test_bandit_chase.gd` (starts in APPROACH; acquisition moved to the new file), `tests/run_tests.gd`.

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` then `godot_ci.py tests` (Godot 4.7.2 headless) | 1006 passed, 0 failed (baseline 764; the extra tests are the new robber file plus the existing per-block sorting tests now covering 4 more blocks) | `godot-ci-logs/tests-builtin.log` |
| `tests/test_bandit_robber.gd` covers: far spawn, 4 blockers as colliders, spawn/patrol clear, routes (choke, north, south), patrol loop + look-around + stop-to-turn, narrow cone, close-sense, wall and rock block detection, NOTICE delay, slower re-acquisition, wall navigation with 0 slide collisions, threaten + robber line, telegraphed two-swing combo, evading by leaving the frozen arc, dodge/jump evade, no hit through walls, double flicker order and distance, hop never ends in a blocker, hit cancels retreat, search then return, leash, profile values, no stuck events | pass | same log |
| `validate_godot_project.py --project .` | no errors reported | console |
| `godot_ci.py export` Web build to a temp dir | exported | `~/.aki/tmp/shinobi-export-bandit` |
| `controls-probe.mjs` against that build | VERDICT PASS (movement, jump, dodge, camera checks) | console |
| `bandit-probe.mjs` (real Chromium, real key presses): player walks through the choke to the Bandit | all 14 checks true: far at start (>1000 px), PATROL at start, NOTICE, APPROACH, THREATEN, robber line, ATTACK, intent exposed, run and idle animations, 0 stuck, 0 console errors. States seen: PATROL, NOTICE, APPROACH, THREATEN, ATTACK, REPOSITION. 3 swings, 4 hits landed on the idle player | screenshots `orders/Aki/reports/assets/2026-10-21-bandit-robber/` |

## Issues encountered
- A first test run exposed that stop-to-turn pauses also applied while chasing; chasing now turns instantly. Several test coordinates were inside existing blocks (fixed in the test, not the game).
- The double flicker did not occur in the browser run (25% chance per combo, 3 combos); it is covered deterministically in the Godot tests only. I have not seen it play in a browser.
- **Dependency**: Orcha's Body Flicker VFX (PR #61 is a preview, not merged). The hop currently reuses the existing `ninja_evade` streak plus a near-invisible body for 0.09 s, a temporary visual. Swap it for Orcha's API once it lands.
- **Art**: no dedicated alert/threaten/attack/walk/flicker clips exist. Tells are code-drawn overlays on the run/idle art. Requested in `orders/Codex/2026-10-21-bandit-level1-action-art.md`.
- The kunai combat PRs are not on main, so the Bandit's "kunai" attack is an arc swing with a telegraph, not a kunai animation.
- I cannot judge feel. Timings are first guesses for the owner to tune in `enemy_intelligence.gd`.
- The headless renderer runs about 5 fps, so the browser run proves logic and visuals, not smoothness. Gamepad was not tested.

- CI's controls probe failed once (wall-stops-player: y 135 -> 117). The probe sprints right for longer in CI than locally and then walks up, and a rock at y -20..90 was directly above it. I moved that rock to y -70..40 (off the y=135 lane) and re-ran: tests 1006/0, controls probe PASS, bandit probe 14/14.

## Questions for project owner
- Should a landed hit have any consequence beyond the tint and shove (player HP is out of scope under the locked rules)?
- Is a 25% retreat rate right for "rare"?

## Outstanding work / next steps
Codex action art; swap to Orcha's Body Flicker; tune timings after owner playtest; Fluidity Milestone B stays held until the owner confirms the jump fix.

## Live deployment
Pending (filled after merge and deploy verification).
