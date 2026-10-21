# ORDER — Combat Camera Feedback Animation Prototype
- **Agent:** Kiro
- **Status:** QUEUED
- **Priority:** P1
- **Owner:** Kiro, camera animation only
- **Dependencies:** Existing close-camera implementation; Aki's combat hit events.

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
