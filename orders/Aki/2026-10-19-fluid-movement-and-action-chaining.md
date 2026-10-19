# ORDER — Fluid Movement and Action Chaining
- Agent: Aki
- Status: DONE
- Priority: P0
- Owner: Aki
- Branch/PR: aki/fluid-movement-action-chaining / #29
- Dependencies: player_128 live (PR #25), dodge/jump + courtyard ground tile v1 (PR #26), ground
  tileset + HUD fix (PR #27/#28)

## Objective
Shinobi Rush movement felt disconnected: running into a jump or dodge stopped the character
before the action played. Fix jump and dodge so movement and actions flow continuously, with
preserved momentum, direct RUN->JUMP / RUN->DODGE animation transitions, a short input buffer,
and no unwanted idle frames.

## Scope / Files owned
- `scripts/player/player_controller.gd`: jump/dodge state machine, velocity handling, input
  buffering, jump visual-elevation offset.
- `tests/run_tests.gd`: new coverage for the order's "Validate gameplay feel" sequences.
- Do not touch: `scripts/camera/camera_preset.gd`, Kiro's Block/BlockRear occlusion, Codex's
  animation assets (frame content flagged as an art issue instead, see report).

## Acceptance Criteria / Tests
- No visible stopping before jump or dodge; no idle frames between actions.
- Jump and dodge move the character through the world; momentum preserved/steerable in air;
  dodge produces real directional displacement with a burst + recovery curve.
- Landing/dodge recovery resume the correct locomotion state immediately.
- Wall collision preserved for both actions; no clipping.
- Input buffer (100-150ms) so a press slightly before an action is legal still fires.
- `validate_godot_project.py` clean; `godot_ci.py tests` 493 (baseline) + new coverage, 0 failed;
  Web export + smoke test clean; before/after movement demonstration captured.

## Handoff / Notes
Codex/art flag: both `jump` and `dodge` manifest animations have a baked-in static windup at
the start of the authored frames (jump: ~5/24 frames, dodge: ~3/12 frames) — see report for
exact frame ranges. Movement code now carries the character through those frames instead of
also stopping, but trimming/re-timing the frames themselves is Codex's lane, not fixed here.
