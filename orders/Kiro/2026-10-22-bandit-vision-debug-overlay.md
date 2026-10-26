# KIRO — P0 Bandit vision debug overlay for live gameplay testing

- **Owner:** Kiro (debug visualization / camera presentation)
- **Status:** DONE (overlay merged; second detection channel documented as a named limit and drawn by the Sense vision overlay; closed by Aki while Kiro was out, 2026-10-22)
- **Priority:** P0
- **Date:** 2026-10-22
- **Requested by owner:** “For the game test I want to be able to see what the bandit's in-game vision is.”

## Goal
Give the player/developer a **toggleable, real-time visualization of exactly what the Level 1 Bandit AI can see**, in the real playable training arena. This is a **debug-only visualization**, not a new detection system or a permanent combat effect.

## Required visualization
1. Draw the Bandit's actual **vision cone / detection region** anchored to the Bandit's eyes/position, rotating with its current facing and following it while it patrols, turns, pursues, or searches. The overlay must be correct for the project's **2D three-quarter overhead / faux-isometric** camera, not a side-scroller.
2. Use the **real detection distance, FOV angle, line-of-sight rays and occlusion decisions** from `scripts/enemy/bandit.gd` / Aki's current AI; do not invent a pretty cone that disagrees with detection logic. If the implementation uses distance-only detection or an approximate facing check, expose the truth and coordinate a minimal read-only interface with Aki. Never silently change AI tuning to fit the visualization.
3. Walls, rocks and other actual collision blockers should visibly **clip/occlude** the sight overlay. Do not show visibility through solid walls. If full polygon clipping is impractical, use clearly labeled sampled rays / LOS debug and accurately distinguish occluded from visible areas; no misleading full cone.
4. Make states instantly readable: **patrolling/not alert**, **suspicious/acquiring**, **player detected**, **lost target/searching**, and **returning**. Provide distinct, colorblind-friendly colors plus text/state indicators; show player marker only when actually detected. Optional small label for detection distance and current intelligence level.
5. Add an in-game **toggle** (suggest **F6**, provided no conflict with existing controls) and a visible button or checkbox in the existing debug/test HUD so browser/mobile testers can use it. Default OFF; no debug drawing in release gameplay unless developer-enabled.
6. Debug visuals must update every frame without leaving ghost polygons when the Bandit dies, despawns, changes scene, or the debug view is turned off. Overlay must not interfere with clicks, input, camera tracking, collision, or gameplay performance.
7. Must work in the **actual normal arena** with the Bandit spawned far across the map and Aki's temporary collision walls. Test behind a wall, approaching from behind, at max detection range, and while fleeing.

## Boundaries and ownership
- Kiro owns debug overlay/UI and any minimal read-only camera or debug presentation wiring.
- Aki owns AI perception, collision, nav, and Bandit behavior. Coordinate if Bandit needs to expose `facing_vector`, `vision_range`, `vision_half_angle`, `can_see_player`, `last_seen_position`, `current_ai_state`, etc.
- Codex owns art/animations. No new art assets required. Don't modify production sprite palettes or the approved camera.
- Inspect existing `scripts/enemy/bandit.gd`, `scripts/arena/training_arena.gd`, `scenes/arena/training_arena.tscn`, debug HUD, and WebBridge/telemetry before implementation.

## Acceptance tests
- In the live browser game, toggle the overlay and **see the Bandit's sight region moving and rotating** as the Bandit moves.
- A player outside range / behind wall / behind Bandit's facing is not shown as detected unless the **actual AI** detects them; any discrepancy must be logged and fixed with Aki, not hidden by overlay art.
- When player crosses the true vision boundary, debug state visibly transitions in sync with Bandit behavior; LOS through blockers remains correctly represented.
- Toggle ON/OFF repeatedly, restart arena, open/close other debug panels, verify no residual geometry or performance issues.
- Automated tests, Godot import, Web export, actual browser keyboard/button smoke, live build verification. Record screenshots/clip and deployed SHA.
- Report `orders/Kiro/reports/2026-10-22-bandit-vision-debug-overlay-report.md`; create implementation PR and merge/deploy through required checks before marking DONE.

## Agent process
Read `orders/README.md` and `orders/Kiro/README.md` first. Work from merged `main`; follow ownership rules, don't force merges or bypass checks, and provide owner-playable proof. If the AI data interface is missing, coordinate with Aki and report precise dependency instead of faking the sight cone.

## Status log
- 2026-10-22 Kiro: QUEUED -> IN_PROGRESS. Read the order, `orders/README.md` and `orders/Kiro/README.md`, then audited `scripts/enemy/bandit.gd` (main 05c7c8f): sight is decided once per physics tick in `_update_perception` (224-231) through the public `can_see` (236-246) and `line_clear_to` (250-259); the cone applies only while the Bandit is not chasing, a literal `1.35` widens the reach to 945 px while it chases, and the ray runs at eye height against every body except the Bandit and the player. Everything the overlay needs is public (state, facing8, profile, sees_player, last_seen, can_see), so `scripts/enemy/**` is NOT touched and nothing is asked of Aki except the optional hint in the report (expose the 1.35 and the chasing list). Built a polygon from the AI's own numbers and ray query (`BanditVisionRegion`), a world-space drawing node (`BanditVisionOverlay`, Okabe-Ito colours plus an outline style and a text per state) and the switch (`BanditVisionToggle`: runtime action, always-visible button, `?vision=1`, `vision_*` telemetry). The toggle key is F2, not the suggested F6: F6 is the address-bar key of Chrome, Edge and Firefox and a headed browser cannot be driven here, so "no conflict" could not be shown; the button is the guaranteed path.
- 2026-10-22 Kiro: IN_PROGRESS -> REVIEW. Whole suite 1167 passed, 0 failed (baseline on main 1045, +122 new checks in `tests/test_bandit_vision_overlay.gd`). Oracle in the real arena: 136,044 sampled player positions in 204 configurations, overlay region against the live `can_see`: 0 disagreements outside the stated 1 px band and 1 inside it (0.05 px from the AI's own boundary). Five temporary mutations (polygon ignores walls, wrong half-angle, dead Bandit keeps its polygon, wrong chase multiplier, OFF only hides) went red (13 / 3 / 4 / 9 / 8 checks) and were restored byte-identically. Local Web export of 5ef94fb built like CI: controls probe 30/30 PASS (23 existing + 7 new). Real-key scenario on that export, 746 published frames: the overlay, the AI's `sees_player`, the AI's `can_see` and an independent model agreed on every frame; a detection from behind came at 91.6 px (unseen at 171.9 px with the Bandit facing away), the cone edge flipped at 696.5 px, the chase edge at 949.3 px, a flee went lost sight -> SEARCH -> RETURN -> PATROL, 41 toggles by F2 and the button left the node count at 155 OFF / 156 ON, and a Bandit killed with real key presses left nothing drawn or published. Findings for Aki, none an overlay defect: the 1.35 literal and the chasing list are mirrored, the chase leash ends a chase in RETURN while the Bandit still sees the player, EVADE and HIT_REACT skip the sight evaluation. Report: `orders/Kiro/reports/2026-10-22-bandit-vision-debug-overlay-report.md`; docs: `docs/development/BANDIT_VISION_OVERLAY.md`. Not verified: real GPU rendering, a headed browser (F6), the owner's own play. Not DONE: the independent review, required CI on the PR head, the merge and the live check come first.
