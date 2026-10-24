# Jump launch regression report (P0)

Order: `orders/Aki/2026-10-20-fix-excessive-jump-launch.md`. Owner report: "jumping launches player super far".

## Root cause
The jump lasts as long as its art: 24 frames at 12 fps = **2.0 s**. In the air the controller only steered
toward the held direction and **never braked**, and `_begin_jump()` deliberately keeps entry velocity. So a
sprint jump carried full sprint speed (607.5 px/s) for 2 s = ~1245 px; a walk jump 393.8 px/s = ~807 px
(~8-11 body heights). Dodge-burst speed also carried straight through (no cap). No code multiplied or
doubled velocity: it is "no air limit x a 2 s jump". The aerial attack (Milestone A) kept that same uncapped
velocity, so it inherited the distance but did not add to it (sprint jump + air attack 1255 px vs 1245 px
without). The 2 s duration comes from the accepted jump art and was left untouched.

## Fix (scripts/player/player_controller.gd)
New shared `_air_move()` used by JUMP and AIR_ATTACK:
- `jump_air_speed_cap = WALK_SPEED * 0.4` (157.5 px/s). Documented export.
- Entry speed above the cap (sprint, dodge burst) is braked at `jump_air_brake` (ACCELERATION * 1.5),
  smoothly (sprint 607 -> cap in ~0.3 s), never snapped, never zeroed.
- Held input steers toward `input * cap` at the existing air-control rate; no input applies a light
  `jump_air_drag` so a released jump settles.
- Aerial attack applies no lunge and no air acceleration beyond the cap. Landing adds no impulse.
Result: a jump travels at most ~330-350 px over its 2 s, about 3 body heights.

## Measurements (60 Hz headless, `tests/test_jump.gd`, world px from jump press to landing)
| Variant | BEFORE disp | AFTER disp | BEFORE late speed | AFTER late speed |
|---|---|---|---|---|
| standing | 0.0 | 0.0 | 0 | 0 |
| walk | 807.2 | 334.0 | 393.8 | 157.5 |
| run / sprint | 1245.4 | 350.4 | 607.5 | 157.5 |
| sprint + air attack | 1255.5 | 353.0 | 607.5 | 157.5 |
| walk + air attack | 813.8 | 336.6 | 393.8 | 157.5 |
| direction change mid-jump | 804.2 | 242.0 | 607.5 | 157.5 (velocity reverses, no snap) |
| dodge -> jump | 813.8 | 340.5 | 393.8 | 157.5 (burst does not persist) |
| 3 sprint jumps in a row | 3158.7 | 1097.1 | 607.5 | 157.5 (no stacking) |

Jump duration 120 ticks (2.0 s) before and after. Tick-rate check (manual, 30/60/120 Hz, sprint jump, run
while the cap was still 0.5x walk): 444 / 428 / 417 px, within 7%; before the fix 1256 / 1245 / 1230.

## Browser evidence (Godot Web export, real Chromium, `?camera=close`, fresh spawn per case, http-served)
| Variant | BEFORE (main 63bbd6c) | AFTER |
|---|---|---|
| standing | 0.0 px | 0.0 px |
| walk | 958 px | 422 px |
| sprint | 1377 px | 461 px |
| sprint + air attack | 1357 px | 464 px |

Sampled by polling at the headless ~5 fps renderer, so values carry a few tens of px of noise (run-up and
polling lag); the numeric unit measurements above are the authoritative figures. 0 console/page errors.
Screenshots: `~/.aki/tmp/jump-before.png`, `jump-jumpfix.png` (local, not committed).

## Commands and results
- `python3 scripts/ci/godot_ci.py tests ...`: **571 passed, 0 failed** (was 548).
- `python3 scripts/ci/validate_godot_project.py --project .`: PASS.
- `godot_ci.py export` (web) then `node scripts/ci/smoke/controls-probe.mjs`: VERDICT PASS (incl. camera close).
- Two existing assertions were retargeted, not weakened in intent: "jump momentum survives the swing" and
  "velocity never collapses toward 0 while airborne" now compare against the air cap instead of walk speed,
  since air speed is now deliberately capped.

## Issues / limitations
- No gamepad hardware: keyboard only. A controller uses the same actions and the same `_air_move`.
- Headless renderer is ~5 fps, so feel cannot be judged; only physics numbers and browser positions.
- A test that changes `Engine.physics_ticks_per_second` wedged the headless runner intermittently, so it is
  not in the CI suite (run manually, numbers above).

## Questions for Chief / owner
1. Is 0.4 x walk (about 3 body heights per jump) the intended reach? It is one export, `jump_air_speed_cap`.
2. Jump animation still restarts from frame 0 after an air attack (follow-up; not changed in this P0 fix).
3. Should the 2.0 s jump art be shortened by Codex? Hang time is what made the old bug so large.

## Commits / PR / deploy
PR #47, merge commit `91eb294f8c64192fe6b966b2f63486be01916725`. Godot CI run 39585195612 passed every
job including the post-deploy live smoke test. Live `build-info.json` `commit_sha` = `91eb294...`. A live
Chromium sprint jump travelled about 437 px (was about 1377 px), 0 errors.

## Follow-up (2026-10-21): shorter jump + animation phase
Branch `aki/jump-duration-and-anim-resume`.
- `jump_duration = 0.85 s` (owner target 0.7-1.0 s). The 24-frame art is compressed to it: the sprite
  frame now follows jump progress instead of free-running, so no frames are lost and it cannot restart.
- Air attack: until `air_attack` art exists the swing keeps showing the jump at its current phase. Before,
  it dropped to the placeholder figure for the swing and then restarted `jump` from frame 0 (no
  `air_attack` sheet, and `show_animation` resets to frame 0 on every animation switch).
- Cap kept at 0.4x walk as instructed. Distances (60 Hz headless): walk 150 px, sprint 167 px, sprint +
  air attack 169 px, dodge -> jump 157 px, 3 sprint jumps 546 px. Bounded and non-stacking.
- Tests: new `jump anim` checks (measured 0.90 s incl. tap frames, inside 0.7-1.0; frame never rewinds
  across the air attack; reaches frame 23; placeholder never shown). Suite 748 / 0.
- Codex request filed: `orders/Codex/2026-10-21-jump-recut-and-air-attack-art.md`.
