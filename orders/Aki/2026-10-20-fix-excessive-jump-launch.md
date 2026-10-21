# ORDER — P0 Regression: Jump Launches Player Excessive Distance

- **Agent:** Aki
- **Status:** QUEUED
- **Priority:** P0 — fix before Combat Fluidity Milestone B
- **Owner:** Aki (gameplay)
- **Context:** Owner directly playtested after Milestone A and reported: **"jumping launches player super far"**. Treat this as a real user-observed regression. Do not assume the exact root cause without reproducing it.

## Objective
Restore a short, responsive, predictable jump with reasonable displacement in the faux-isometric world. Preserve the newly added aerial attack and run→jump→attack→land→run flow without launching the player across the map.

## Investigation
1. Reproduce in the current browser build and local Godot build with **standing jump, walking jump, running jump, R1 sprint jump, run→jump→air attack, and jump while changing direction**. Capture screen recording, initial/peak horizontal velocity, world displacement, jump duration, frame delta and current states.
2. Audit `scripts/player/player_controller.gd` and relevant movement constants: jump entry, sprint/dash carryover, acceleration, air steering, friction, any lunge impulse, gravity/vertical presentation, collision and state transitions. Determine whether velocity is multiplied, added twice, not capped, or allowed to persist too long. Compare with pre-Milestone-A behavior if possible.
3. Distinguish **actual world-space travel** from sprite-only vertical jump height or camera-follow movement. Confirm root cause using instrumentation, not speculation.
4. Fix minimal relevant logic. Jump must not inherit dodge burst or dash-attack lunge incorrectly; clamp/cap air horizontal movement to a clearly documented intentional value and keep controlled steering. Avoid artificially snapping to zero or destroying momentum. Ensure aerial attacks do not apply ground-attack lunge or unwanted air acceleration.
5. If the airborne visual restarts jump animation from frame 0 after air attack, fix phase-aware resume if it can be done safely without expanding scope; otherwise log separate art/integration follow-up.

## Acceptance criteria / testing
- Standing jump remains near starting ground position except intended steering.
- Walk/run/sprint jumps travel controlled, bounded distances, not excessive map-crossing launches.
- Air attack does not increase horizontal speed or total jump distance unexpectedly.
- No extra impulse when landing or transitioning back to MOVE/SPRINT/IDLE.
- Repeated jumps, rapid directional changes, and dodge→jump do not stack velocities.
- Add regression tests measuring velocity and displacement across jump variants and air attack, including at 60Hz physics and varying render frame rate.
- Playtest keyboard and controller if available; test Godot Web export in actual browser. Verify the owner-reported failure is gone at approved close-camera zoom. Document any controller-test limitations.
- Run repository CI/tests, record actual commands/results, produce `orders/Aki/reports/2026-10-20-jump-launch-regression-report.md` with before/after measurements and browser evidence. Commit only after tests and follow repo PR, merge, deployment and live verification policy.

## Dependencies / Handoff
- Prioritize over Milestone B. Coordinate only if another agent is editing the same movement controller; no Codex/Kiro/Orcha changes required.
- Report root cause and numerical before/after displacement to owner; do not declare fixed solely because unit tests pass.
