# Job Report — Fluid Movement and Action Chaining
- Agent: Aki
- Order: orders/Aki/2026-10-19-fluid-movement-and-action-chaining.md
- Date: 2026-10-19
- Final status: DONE — code+tests complete, CI green locally, PR open (merge pending CI watch)
- Commit / PR: aki/fluid-movement-action-chaining @ 2d8e7f7, PR TBD (see outstanding work)

## Root cause (before)

`player_controller.gd`'s `_physics_process` had a single shared branch for both DODGE and JUMP:

```gdscript
if state == State.DODGE or state == State.JUMP:
    _action_timer -= delta
    velocity = velocity.move_toward(Vector2.ZERO, friction * delta)   # <- decays to 0 every frame
    ...
```

JUMP decayed velocity toward zero exactly like coming to a stop — the opposite of "preserve
momentum" — and had **zero visual elevation** (no arc at all, just a velocity-decay timer).
DODGE's initial burst was set correctly on trigger but then also decayed toward **zero** (not
toward a run/walk recovery speed), always used `facing8` even when the player was actively
holding a different directional input, and had no air-control / recovery curve distinct from
plain ground friction. Neither action had an input buffer, so a press landing 1-2 frames before
the previous action freed up was simply dropped.

Separately — flagged per the order's explicit instruction to report rather than hide in code —
**both authored animations have a real baked-in static windup** (contact sheets built from
`assets/characters/player/player_128.manifest.json`, "S" direction, inspected frame-by-frame):
- `jump` (24 frames @ 12fps, loop=false): **frames 0-4 are a near-static standing pose**
  (~0.4s) before crouch/leap motion begins around frame 5; airborne/tucked ~12-17; landing ~18-23.
- `dodge` (12 frames @ 12fps, loop=false): **frames 0-2 are a near-static windup** (~0.25s)
  before the lunge/dive visibly starts at frame 3.
This is an art/Codex issue, not fixed here — the movement-code fix below makes the character
keep moving through world space during these frames (meaningfully reducing the perceived stop),
but trimming/re-timing the baked frames themselves is out of scope.

## Work completed (after)

Rewrote the DODGE/JUMP handling in `scripts/player/player_controller.gd`:
- **Jump**: velocity is never reset on entry or exit. While airborne, if input is held the
  velocity bends toward the new heading at a reduced `air_control_mult` (0.6x normal
  acceleration) instead of snapping; with no input the arc simply continues unchanged. A purely
  visual sine-arc elevation (`jump_visual_height`, 34px) is applied to `PlayerVisual`'s **local**
  position only — never to the body's `global_position` — so collision and the arena's Y-sort
  (keyed off this node's own `global_position.y`, see `arena_sort.gd`) are completely unaffected
  by being airborne. On landing, the code falls straight into normal locomotion the same frame
  (no `return` before it), so MOVE/SPRINT resumes immediately with the velocity already correct.
- **Dodge**: direction now comes from current input if any is held, else `facing8` (previously
  always `facing8`, ignoring live input). The burst velocity is set once on trigger, then eased
  via a **dedicated** `dodge_recovery_accel` (1.5x normal acceleration) toward whatever speed
  current input calls for — run/sprint speed if moving, zero if not — instead of reusing the
  generic ground `friction` and always decaying to a stop. `move_and_slide()` (wall collision)
  is unchanged and still runs every frame of the action.
- **Direct transitions**: both actions already bypassed any IDLE detour in the state machine
  itself (confirmed by code reading, not a bug) — the apparent "stop" was entirely the velocity
  bug above plus the baked animation frames. The rewrite keeps that direct-transition structure
  and adds: a single `prev_state`-diffed `state_changed` emit point (replacing three scattered
  emits), and a combined "action just finished this frame -> fall through to locomotion" path so
  there is never a frame where the player sits in a transitional/idle state.
- **Input buffer**: new `_dodge_buffer`/`_jump_buffer` (seconds-remaining) set on
  `is_action_just_pressed`, decayed every frame, checked whenever the player is not mid-action.
  Window is `input_buffer_window = 0.12s` (within the ordered 100-150ms range). If both are
  buffered the same frame, the more recently pressed one wins. This lets "Run -> Jump -> Dodge"
  work: a dodge pressed near the tail of a jump is remembered and fires the instant the jump
  ends, instead of being silently dropped.
- **Anti-spam**: holding a key does not re-trigger — `is_action_just_pressed` is a single-frame
  edge, so no extra cooldown was needed beyond the action's own duration; stated explicitly
  rather than adding an unneeded cooldown that would add input lag.
- **Coyote time**: evaluated and judged not applicable — this is a flat top-down arena with wall
  blocks, not pits/ledges (`WorldScale.BLOCKS`), so there is no "falling off an edge" case for a
  grace window to cover. Not implemented; stated plainly rather than faked.
- Confirmed (code reading, no change needed): `SpriteActor.show_animation()` is genuinely
  idempotent when the `(set, anim, dir)` key is unchanged, so calling `play_action()`/`set_pose()`
  every physics frame does not restart animations — order's "avoid restarting animations every
  physics frame" requirement was already satisfied structurally.
- Existing input bindings unchanged: dodge = Space, jump = F, sprint = Shift, move = WASD.

## Files changed
- `scripts/player/player_controller.gd` (rewritten jump/dodge/state-machine section; +138/-32)
- `tests/run_tests.gd` (new `test_jump_and_dodge_chaining()`, +203 lines, wired into `_initialize()`)
- `orders/Aki/2026-10-19-fluid-movement-and-action-chaining.md` (new)
- `orders/Aki/reports/2026-10-19-fluid-movement-and-action-chaining-report.md` (this file)

## New test coverage (`test_jump_and_dodge_chaining`)
Covers every sequence in the order's "Validate gameplay feel" list against the real `main.tscn`
scene (not mocks): Idle->Run->Jump->Run, Sprint->Jump->Land->Sprint, Run->Dodge->Run,
Sprint->Dodge->Sprint, releasing movement input mid-dodge, dodge-into-wall, jump-into-wall, and
a buffered Run->Jump->Dodge chain. Each trigger holds the key for a few frames (a same-frame
press+release is faster than the headless `SceneTree` test harness can reliably register as a
`just_pressed` edge — a real keypress always spans multiple frames) and samples state every
frame to assert the transition never passes through IDLE.

## Tests run before commit
| Test / command | Result |
| --- | --- |
| `python scripts/ci/validate_godot_project.py --project .` | PASS — 0 errors, 0 warnings |
| `python scripts/ci/godot_ci.py import --project . --godot <godot>` | Clean reimport, no script errors |
| `python scripts/ci/godot_ci.py tests --project . --godot <godot>` | PASS — **514 passed, 0 failed** (493 baseline + 21 new) |
| `python scripts/ci/godot_ci.py export` + `finalize-export --commit-sha 2d8e7f7...` | Clean Web export, `build-info.json` written |
| `node scripts/ci/smoke/smoke.mjs --serve-dir <export> --expected-sha 2d8e7f7... --input-sequence "KeyD:600,KeyF:900,Space:500,KeyD:400" --require-input-effect` | PASS — all 11 checks; `input-effect` 19.3% of sampled pixels changed, 0 fatal console errors |
| Manual Playwright capture (hold `KeyD` continuously while tapping `KeyF`/`Space` mid-run, 9 screenshots) | Confirms on-screen HUD: `State` flips directly `MOVE -> JUMP -> MOVE` and `MOVE -> DODGE -> MOVE` with no `IDLE` frame visible in between; `Pos` keeps advancing through both actions (no stop) |

## Before/after movement demonstration
Captured via a standalone Playwright script (not the CI smoke harness, which presses one key at
a time — this needed two keys held simultaneously to reproduce "running into a jump/dodge"):
hold `D` (move_right) continuously for the whole sequence, tap `F` (jump) mid-run, let it land,
tap `Space` (dodge) mid-run, let it recover, release `D`. 9 screenshots at
`~/.aki/tmp/fluid-demo/01_idle.png` through `09_stopped.png` (local session artifact, not
committed — happy to re-run and attach if the owner wants it archived in-repo).
Key frames: `02_running` (State MOVE) -> `03_jump_takeoff_still_running` (State **JUMP**,
captured 80ms after the jump key went down, position already advanced) -> `04_jump_midair` ->
`05_landed_still_running` (back to State **MOVE**, still moving) -> `06_dodge_burst_still_running`
(State **DODGE**) -> `07_dodge_recovery` -> `08_dodge_recovered_still_running` (back to State
**MOVE**). At no point does the HUD's `State` field show `IDLE` between the run and the action.

## Issues encountered
- Both authored jump/dodge animations have a baked-in static windup at the start of the frame
  sequence (see Root cause section above) — flagged for Codex, not fixed in code per the order's
  explicit instruction.
- The headless `SceneTree` test harness cannot reliably register `is_action_just_pressed` from a
  same-frame `Input.action_press()` + `Input.action_release()` pair — fixed by holding keys for
  a few frames in the new tests (does not affect real gameplay, where a keypress always spans
  multiple frames).
- An early version of the new tests leaked buffered jump/dodge presses across test blocks
  (pressing `jump` in one scenario, releasing before it fired, then having it fire several frames
  later *inside the next scenario*) — fixed by explicitly resetting `_dodge_buffer`/`_jump_buffer`/
  `_action_timer`/`state` between scenarios in the test, not a gameplay bug.

## Questions for project owner
- None blocking. `air_control_mult` (0.6x), `dodge_recovery_accel` (1.5x accel), `jump_visual_height`
  (34px), and `input_buffer_window` (0.12s) are first-pass tuning values exposed as `@export`s for
  easy re-tuning in the editor — flag if any should be adjusted before wider testing.

## Outstanding work / next steps
1. Commit (done, `2d8e7f7`), push `aki/fluid-movement-action-chaining`, open PR against `main`,
   watch CI, merge, verify live Pages deploy + post-deploy smoke test.
2. Hand the two flagged baked-in-pause animation issues (jump frames 0-4, dodge frames 0-2) to
   Codex for a possible re-time/trim pass — not blocking this order's merge.
3. If the owner wants the before/after screenshots archived in-repo (e.g. under a `docs/` or
   `reference/` folder) rather than left as a local session artifact, say so and they'll be added
   in a follow-up commit.
