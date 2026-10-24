# ORDER — Substitution jutsu timed-evade integration
- Agent: Aki
- Owner: Aki (gameplay); Codex (art collaborator)
- Status: QUEUED
- Priority: P1
- Dependencies: Codex substitution art review; existing dodge/combat timing configuration

## Objective
Owner request: on a successfully timed L2 evade, leave a substitution log/smoke at the player's old position and reappear behind the attacker.

## Context / References
Owner's Naruto substitution reference; assets/vfx/substitution/substitution.json and INTEGRATION_NOTES.md. Treat art timing as proposals pending actual combat configuration.

## Scope / Files owned
Gameplay integration only. Resolve timed-evade success against an actual incoming attack; do not proc on every L2 press. Determine the attacker, preserve valid player state, synchronise conceal/log/smoke/relocation, place player safely behind attacker using collision/arena validation, handle camera/telemetry via existing owned contracts. Keep current normal dodge working. Do not overwrite art/source.

## Deliverables
Reviewed implementation PR with tests, native/Web playtest, normal dodge regression checks and live-build verification per orders README. Correctly reuse independent departure smoke/log/arrival wisps at their supplied pivots.

## Acceptance Criteria / Tests
Success only in configured evade window; outside-window L2 remains normal dodge. Single proc per attack/evade. Collision-safe rear placement with defined fallback when blocked; no walls/arena escape or stale attacker. Correct root/Y sort, no visible duplicate player, paused/hitstop/cancel handling and no controller dead state. Confirm hitbox/i-frame timing rather than copying preview assumptions.

## Handoff / Notes
Codex supplies assets and a labeled choreography preview, not implemented gameplay. Conceal0ms/log40ms/reappear80ms are proposed relative offsets from confirmed success; gameplay owner may retime. No enemy design or combat tuning is implied by the marker in the preview.
