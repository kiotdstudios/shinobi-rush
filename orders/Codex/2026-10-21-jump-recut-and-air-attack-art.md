# ORDER — Re-cut the player jump to ~0.85 s and deliver `air_attack` art

- Agent: Codex
- Status: QUEUED
- Priority: P1
- Owner: Codex (art), requested by Aki on the owner's instruction (jump should last about 0.7-1.0 s)
- Branch/PR: new branch `codex/jump-air-attack-art`, normal reviewed PR
- Dependencies: Aki PR (jump duration + progress-driven jump frames) merged to main; weapon direction per `orders/Codex/2026-10-21-kunai-primary-combat-animation.md` (air attack should match the approved kunai one-handed style, not the sword)

## Objective
1. Jump: the current `jump` sheet is 24 frames at 12 fps (2.0 s). Gameplay now plays it in **0.85 s** by stretching the frames to the jump's progress (about 28 fps equivalent), so it already works, but the pose timing is not authored for that. Re-cut it for 0.85 s: quick take-off, short apex hold, readable landing absorb. 12 frames at 14 fps (0.857 s) is the suggested target; the controller drives the frame from progress, so any frame count works.
2. `air_attack`: a one-handed aerial strike that can start at any point of the jump arc. Aki's AttackDef: startup 5 ticks / active 4 / recovery 10 at 60 Hz (about 0.32 s total), played over the jump; the body keeps the jump pose underneath. Needs 8 directions, 128x128, same root as the other player sheets.

## Context / References
`scripts/player/player_controller.gd` (`jump_duration`, `_play_jump_visual`, AIR_ATTACK), `assets/characters/player/player_128.manifest.json`, `orders/Aki/reports/2026-10-20-jump-launch-regression-report.md`.

## Scope / Files owned
Player jump and air_attack sheets plus manifest entries only. No controller, camera or combat-timing changes; Aki owns timing and will adapt `jump_duration` to what you deliver.

## Deliverables
Sheets + manifest, one-direction proof for approval before the full eight (same gate as the kunai order), report with frame counts and fps.

## Acceptance Criteria / Tests
Manifest validates (`scripts/ci/validate_godot_project.py`), nearest filtering, feet stay on the anchor through the whole arc, and in the live build a jump -> air attack -> land -> run reads as one continuous motion. Until `air_attack` exists, the game keeps showing the jump pose during the swing (no placeholder).

## Handoff / Notes
Tell Aki the final frame count/duration so `jump_duration` can match it exactly. The owner wants the jump short and responsive; please do not lengthen it.
