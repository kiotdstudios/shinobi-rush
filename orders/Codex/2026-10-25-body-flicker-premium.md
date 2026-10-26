# ORDER — Premium Body Flicker dodge presentation
- Agent: Codex
- Owner: Codex
- Status: DONE
- Priority: P1
- Branch/PR: codex/body-flicker-premium / https://github.com/kiotdstudios/shinobi-rush/pull/209
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
Integrated latest-main full native suite: 3251 passed; focused presentation/health/bandit suite: 148 passed. Web: 25 review checks plus normal-game keyboard/recording checks passed; no browser errors. PR209 merged; canonical 4e248c1b deployed and verified.

## Live delivery
PR209 merged as 4e248c1b0c2a2e427eba49dca4c7e2b026ce306c. Main CI 40260710058 passed all jobs, including deploy/postdeploy/gate. Verified the exact public build on 2026-10-25 at 23:10 EDT: 25/25 review checks and 4/4 actual-game keyboard checks, no browser errors. Final native CI: 3266/0. Evidence: docs/visuals/body-flicker-premium/deployment.json, live-proof/, public-before/ and public-after/. Before/after WebM files now record the actual canonical public game, not the local comparison mode.
