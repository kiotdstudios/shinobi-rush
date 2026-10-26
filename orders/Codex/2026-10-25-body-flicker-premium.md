# ORDER — Premium Body Flicker dodge presentation
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/body-flicker-premium
- Dependencies: Existing authoritative player dodge and bandit evade/retreat movement; approved 128px art.

## Objective
Execute the owner's pasted high-quality Body Flicker brief: explosive eight-direction launch, travel, landing and recovery with reusable afterimages, streaks, dust and displacement, integrated and verified in live gameplay.

## Context / References
Owner brief: C:/Users/dielp/.codex/attachments/6b2f6c5f-3a8d-49fe-aa39-763836e71c63/Pasted text.txt. Existing player dodge art, bandit sprint art and independent evade/dust sprites. Preserve character identity and camera style.

## Scope / Files owned
Presentation-only changes to EvadeStreakFx, player/bandit visual binding and the existing player spawn call if necessary. Add isolated real-controller review, tests, documentation and own report. Explicit owner assignment authorizes integration; do not alter input, movement, collision, i-frames, cancels or dash-attack windows.

## Deliverables
Player and bandit shared lightweight VFX, phase-timed poses in eight directions, actual-position afterimages, wall/speed/interruption tests, before/after recordings, normal and half-speed review, PR and canonical live verification.

## Acceptance Criteria / Tests
Immediate gameplay response; recognizable bodies and crisp pixels; no fade-only dash or smoke teleport; no afterimages extrapolated through walls. Preserve timing/hitboxes/input. Test all octants, walls, repeated triggers, cancellation, varied speeds, bandit reuse and cleanup. Run native CI/export/browser gates and verify exact canonical live build before DONE.

## Handoff / Notes
Latest direct high-priority task supersedes stale queued work. Reuse approved body and VFX art where appropriate; presentation timing follows existing action duration rather than changing gameplay to match suggested 0.38s. Player currently 0.30s total, 0.20s movement; bandit 0.20s evade and profile-driven retreat hops.

## Local delivery evidence
Full native suite: 3118 passed; final focused presentation/health/bandit suite: 146 passed. Web: 23 review checks plus normal-game keyboard/recording checks passed; no browser errors. Awaiting reviewed integration and exact canonical deployment verification.
