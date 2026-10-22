# Job Report -- Body Flicker In-Game Preview
- Agent: Orcha
- Order: orders/Orcha/2026-10-21-body-flicker-in-game-preview.md
- Date: 2026-10-21
- Final status: REVIEW -- Godot tests 742/0, Web export + browser smoke test pending
- Commit / PR: branch orcha/body-flicker-in-game-preview

## Work completed
BodyFlickerDemo node + Animation Lab Y-key integration. See full details below.

## Files changed
scripts/vfx/body_flicker_demo.gd (NEW), scripts/ui/animation_lab.gd (+flicker demo), scenes/player/player.tscn (+2 nodes), scripts/camera/combat_camera_director.gd (from dynamic-camera branch), assets/vfx/body_flicker/ (10 PNGs + sidecars).

## Tests run
742 passed, 0 failed (godot_ci.py tests, Godot 4.7.2). Web export pending.

## Issues
1. KEY_B (66) taken by dbg_toggle_telemetry_hud -- switched to KEY_Y (89). 2. GDScript type inference on path string -- fixed. 3. Visual-only prototype: body position not moved (intentional, Aki owns production teleport).

## Report to Chief
Chief -- tests clean 742/0. Key questions for your review of the deployed build:
1. Does departure/travel/arrival read as Body Flicker (extreme speed) not a teleport spell?
2. Is 56px SE travel distance right at close-camera zoom?
3. Art: keep procedural silhouettes, request PixelLab (needs budget approval), or split with Codex?
4. JUTSU camera zoom-in (0.10 delta, 550ms) -- right feel for Body Flicker?

Concern: this PR bundles CombatCameraDirector + Body Flicker. Can split if needed.
Next step: you review browser build after deploy, answer 4 questions, then I expand to 8 directions.
-- Orcha

## Outstanding
Web export + live build verify. 8-direction after owner approval. Optional unit tests for BodyFlickerDemo.
