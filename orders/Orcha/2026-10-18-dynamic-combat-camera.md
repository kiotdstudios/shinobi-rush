# ORDER — Dynamic combat camera director
- Agent: Orcha
- Status: QUEUED
- Priority: P1
- Owner: Orcha (camera system implementation)
- Collaborators: Aki (combat triggers), Codex (animation/VFX markers), Kiro (browser tests/deploy)
- Branch/PR: Dedicated feature branch, PR required
- Dependencies: Existing Godot Camera2D/gameplay project; coordinate if missing

## Objective
Create a premium, responsive, **dynamic combat camera** for light/heavy attacks, perfect dodges, jutsu, finishers and bosses while preserving the game's fixed three-quarter overhead perspective.

## Context / References
Read `docs/gameplay/DYNAMIC_COMBAT_CAMERA.md`, `docs/visuals/CAMERA_AND_ART_DIRECTION.md`, master agent instructions and locked gameplay decisions.

## Scope / Deliverables
- Reusable Godot 4 Camera2D director with configurable event presets, priorities, bounded zoom/offset/shake and clean transitions.
- Smooth attacker/target framing for finishers; robust map-edge clamping, interruption handling and return to exploration camera.
- Exposed reduced-motion, shake and zoom settings.
- Camera telemetry events for the debug logger; Aki integration contract for confirmed-hit/dodge/jutsu/finisher signals.
- Godot demonstration scene or actual game integration; avoid fabricated placeholder project if Godot runtime absent.
- Coordinate cinematic timing/impact cues with Codex and audio/VFX; no copying camera choreography from existing games.

## Acceptance Criteria / Tests
- Responsive gameplay during camera motion; no input or hitbox drift.
- Smooth, cinematic finisher camera with both attacker and victim visible and safe return.
- Priority, rapid-combo, simultaneous-hit and map-edge stress tests.
- Reduced-motion setting and no-shake mode tested.
- Test on Godot Web browser build with gamepad and keyboard when deployment exists.
- Record exact tests, profiling, screenshots/clip, problems and blockers before commit.

## Handoff / Report
Write `orders/Orcha/reports/YYYY-MM-DD-dynamic-combat-camera-report.md`; include branch/PR, camera presets, event names, tests, issues, browser URL/build verification or explicit blocker.
