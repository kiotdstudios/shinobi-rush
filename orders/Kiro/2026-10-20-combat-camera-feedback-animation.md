# ORDER — Combat Camera Feedback Animation Prototype
- **Agent:** Kiro
- **Status:** REVIEW (PR open, NOT merged, NOT DONE: Aki still has to wire the call and the orchestrator verifies the deployed build)
- **Priority:** P1
- **Owner:** Kiro, camera animation only
- **Dependencies:** Existing close-camera implementation; Aki's combat hit events.
- **Branch/PR:** kiro/combat-camera-impact = PR #50 (https://github.com/kiotdstudios/shinobi-rush/pull/50)

## Objective
In parallel with Codex's combat sprites and Orcha's Lightning Clone, implement **one standalone procedural camera-impact animation** for confirmed sword hits. Do not duplicate sprite/VFX work. Keep this small because Kiro has limited remaining execution budget.

## Context / References
Read `orders/README.md`, `orders/Kiro/README.md`, `docs/visuals/CAMERA_AND_ART_DIRECTION.md` and existing camera scripts. The owner's combat reference emphasizes fast, powerful contact; camera must reinforce hits without compromising movement responsiveness.

## Scope
1. Audit existing camera shake and current Kiro camera work; reuse code where possible.
2. Expose a camera-only event/impulse callable by Aki on confirmed contact, with directional kick, intensity and recovery. Starting targets: light hit 2–3 screen pixels for 60–100ms; heavy hit 4–6 pixels for 100–140ms; tune by testing.
3. Optional tiny zoom pulse (max ~1–2%, off by default). Always return to the existing close-camera zoom/framing and follow target; do not alter presets or occlusion.
4. Prevent accumulated drift, jitter, uncontrolled stacking and clipping at screen edges. Provide disable/reduce setting or config.
5. Demonstrate no-hit, light-hit, heavy-hit and three rapid impacts in a minimal test. Do not modify Aki's combat controller, Codex's sprites, Orcha's Lightning Clone, or world/map systems. If integration would conflict, hand Aki a documented event contract instead.

## Deliverables
Reusable camera-impact module, parameter guide, test capture, event handoff for Aki and required report in `orders/Kiro/reports/2026-10-20-combat-camera-feedback-report.md`.

## Acceptance Criteria / Tests
Camera returns to baseline with no residual displacement or zoom; repeated events remain stable; no follow/occlusion/clipping regression; disabling effect leaves gameplay unchanged. Test in Godot and live browser if runtime-visible, document exact results and PR/deployment links. Follow repository pre-commit testing, reporting and integration policy. Report blocked if the scope conflicts with ongoing camera work.

## Handoff
**Kiro:** camera impulse only. **Aki:** confirmed-hit event integration. **Codex:** combat art and Chidori. **Orcha:** Lightning Clone. No new assignments beyond this single small animation.

## Status log
- 2026-10-21 Kiro: QUEUED -> IN_PROGRESS. Audit: no camera shake and no `Camera2D.offset` use exists in `scripts/`; the confirmed-hit site is `PlayerController._check_attack_hits()`. Measured that Godot 4.7.2 adds `Camera2D.offset` after the limit clamp, so the module clamps itself. Wrote `scripts/camera/camera_impact.gd`, lab demo keys `7 8 9 0` (H / G / B would have turned two existing key-collision tests red), `?camera_impact=off|reduced|on` and the `cfx_*` telemetry; 100 in-engine checks in `tests/test_camera_impact.gd` (96 at first, plus 4 for the moving camera added after the review, see the last entry), red under four temporary mutations of the production code (12, 23, 5 and 2 checks failed; the fourth is the review fix). The optional zoom pulse is left out (measured: +1.5 % zoom moves the view 9.6 screen px at the east limit, more than the 5 px kick).
- 2026-10-21 Kiro: IN_PROGRESS -> REVIEW. Local Web export of e2b3114 (main 91eb294 merged): controls probe 22/22 PASS (16 existing + 6 new); light 2.500 px and heavy 5.000 px at the wide and the close preset; a slow-kick screenshot pair matched the published offset to 0.04 px (close) and 0.26 px (wide) and the world returned pixel-identical; whole suite 738 passed, 0 failed after the last merge of main (fa85e93); 742 passed after the review fix (see the last entry). Parameter guide and the event contract for Aki: `docs/development/CAMERA_IMPACT.md`. Report: `orders/Kiro/reports/2026-10-20-combat-camera-feedback-report.md`. PR #50 (https://github.com/kiotdstudios/shinobi-rush/pull/50) open. NOT merged and NOT DONE: nothing calls the module yet (Aki wires the documented call at the confirmed-hit site) and the orchestrator verifies the deployed build.
- 2026-10-21 Kiro: REVIEW (second pass). The independent review of PR #50 at head 4d400fe asked for changes: the edge clamp showed void on a MOVING camera, because `Camera2D.set_offset()` makes the engine advance the position smoothing one extra step for the rendered frame (up to 6.9 world px at the wide zoom and 4.1 at the close zoom, for a few frames, when a hit lands while the player runs into a wall). Fixed in `scripts/camera/camera_impact.gd` with a second clamp pass from the centre the engine reports after the write, a real-frames test (the player walks into the east wall at close and at wide, a heavy hit every 7th frame; red before the fix, green after, red under a fourth mutation), the engine quirk documented in `docs/development/CAMERA_IMPACT.md` and the counts refreshed: whole suite 742 passed, 0 failed (100 `impact` checks); fresh local Web export of the fix commit 16e370e and the controls probe 22/22 PASS. Open question for the first playtest: heavy hits toward a pinned east or west wall give no kick (`KICK_SIGN` -1 is the alternative). Still REVIEW: NOT merged and NOT DONE.
