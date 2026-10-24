# ORDER — Eight-direction kunai combat for player and bandit
- Agent: Codex
- Status: REVIEW
- Priority: P0 — direct owner request; replaces paused chakra work
- Owner: Codex (art, shared visual rig and requested attack-animation wiring)
- Branch/PR: codex/kunai-eight-directions
- Dependencies: current main05dc2f3; approved SE kunai proof; existing128×128 player and bandit designs

## Objective
Extend the existing SE kunai attacks to S/SE/E/NE/N/NW/W/SW and make the same attack choreography and weapon attachment system usable by both player and bandit. Preserve each character's appearance.

## Context / References
Owner rejected both chakra VFX and charge body on2026-10-22, paused that project, and explicitly authorized full-direction kunai plus bandit reuse. This lifts the earlier SE-only expansion gate. Existing approved SE light1/2/3 and dash-attack body/weapon data remain the motion and timing baseline. Approved player turnaround, production directional sprites and red-scarf bandit sprites define identity and camera.

## Scope / Files owned
Directional combat body assets and manifests for both characters; shared data-driven kunai rig/visual component; player attack visual binding and bandit attack visual binding; isolated review and tests. Preserve damage, attack windows, movement, AI state machine and camera logic. Enemy uses its existing slower windup/active/recovery timings with the same poses. Other bandit action-order items remain separate.

## Deliverables
Light1/2/3 and dash attack in all8 headings, per-character body frames, shared black kunai, separate effects, per-frame hand/socket/orientation/draw-order data, timing/contact metadata, reusable visual playback, normal/half-speed two-character review, previews, tests/report/PR/live verification.

## Acceptance Criteria / Tests
Native128×128 RGBA; fixed(64,116) anchor; approved design/scale; no baked shadow or trails; genuine facing-specific art instead of SE fallback/rotating the body; correct weapon grip and behind/front occlusion; unique purposeful frames; reliable interrupted-attack cleanup. Both characters can render all shared attack IDs in all8 directions. Player real attacks and bandit's existing two-swing AI must display aligned body/weapon poses synchronized to their existing gameplay windows. Import/QC/manifest/headless tests, actual Web review/gameplay, required CI and exact-SHA live verification.

## Handoff / Notes
Shared choreography/profile does not mean giving the bandit the player's skin or changing enemy damage/cadence. Preserve the approved SE player art. Chakra PR107 remains draft and paused.

## Local acceptance —2026-10-23
1792 native checks passed,0 failures/engine errors. All384 body references validated;192 paired Web-review poses and real-input player attacks in8 headings plus actual bandit two-swing AI passed. Phone portrait/landscape touch emulation and controls regression passed. Report: reports/2026-10-22-kunai-eight-directions-report.md. PR, CI, deployment and owner visual review pending.
