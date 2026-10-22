# Job Report -- Body Flicker In-Game Preview (Delivery Rules Pass)
- Agent: Orcha
- Order: orders/Orcha/2026-10-21-body-flicker-in-game-preview.md
- Date: 2026-10-21
- Final status: REVIEW -- all local tests PASS; live Pages verification pending PR merge
- Branch: orcha/body-flicker-in-game-preview
- Implementation commit: 8d45f59 (original) + cleanup commit (this report)

## Work completed

### Delivery rules pass (this commit)
Per order 2026-10-21-body-flicker-delivery-rules.md:
- Removed CombatCameraDirector.gd and .uid from this PR (belongs to orcha/dynamic-combat-camera)
- Reverted player_controller.gd and web_bridge.gd to main (those changes came with the camera director)
- Removed CombatCameraDirector node from player.tscn; load_steps corrected to 8
- Removed CombatCameraDirector.notify() call from animation_lab.gd flicker_demo() with a TODO comment
- Added order file: orders/Orcha/2026-10-21-body-flicker-delivery-rules.md

### Body Flicker demo (from commit 8d45f59)
- scripts/vfx/body_flicker_demo.gd: visual-only VFX player; 10 SE frames across 3 phases; hides/restores player visual; cleanup on lab close; no production teleport or combat changes
- scripts/ui/animation_lab.gd: Y key (dbg_body_flicker), Body Flicker row (Normal / 0.5x buttons), cleanup on lab close
- assets/vfx/body_flicker/: 10x 192x192 RGBA PNGs + .import sidecars + manifest + handoff + contact sheet
- scenes/player/player.tscn: BodyFlickerDemo node added, load_steps 8

## Exact file paths (per delivery rules order)
- assets/vfx/body_flicker/depart_000.png through depart_002.png: PRESENT
- assets/vfx/body_flicker/travel_000.png through travel_003.png: PRESENT
- assets/vfx/body_flicker/arrive_000.png through arrive_002.png: PRESENT
- assets/vfx/body_flicker/body_flicker_SE.art.json: PRESENT
- assets/vfx/body_flicker/contact_sheet_SE_proof.png: PRESENT
- assets/vfx/body_flicker/AKI_HANDOFF.md: PRESENT
- scripts/vfx/body_flicker_demo.gd (+.uid): PRESENT
- scripts/ui/animation_lab.gd: PRESENT (Y key + Body Flicker row)
- scenes/player/player.tscn: PRESENT (BodyFlickerDemo node, no CombatCameraDirector)
- orders/Orcha/2026-10-21-body-flicker-in-game-preview.md: PRESENT
- orders/Orcha/reports/2026-10-21-body-flicker-in-game-preview-report.md: PRESENT (this file)
- CombatCameraDirector: NOT in this PR (separate PR: orcha/dynamic-combat-camera)

## Tests run before commit

| Test | Command | Result | Evidence |
| --- | --- | --- | --- |
| Godot project import | godot_ci.py import | PASS -- 0 errors, 0 warnings | Tool output |
| Godot built-in test suite | godot_ci.py tests | PASS -- 742 passed, 0 failed | Tool output |
| Web export | godot_ci.py export + finalize-export | PASS -- 38 MiB, build-info.json written for 8d45f59 | Tool output |
| Browser smoke (controls probe) | smoke.mjs --serve-dir | PASS -- 11/11 checks (PASS), 0 fatal errors | summary.md |
| WebGL 2.0 available | smoke | PASS | WebGL 2.0 (OpenGL ES 3.0 Chromium) |
| Engine starts | smoke | PASS -- overlay removed after 7313 ms | summary.md |
| Canvas visible | smoke | PASS -- 1280x720, drawing buffer 1280x720 | summary.md |
| SHINOBI_READY hook | smoke | PASS -- window.__SHINOBI_READY__ === true | summary.md |
| Canvas not blank | smoke | PASS -- 87 distinct colours | summary.md |
| Input effect | smoke | PASS -- 16.7% pixels changed after KeyD+Space+J | summary.md |
| No fatal console errors | smoke | PASS -- 4 warnings (all WebGL ReadPixels stalls from smoke test itself), 0 fatal | console-log.json |
| Key collision check | Godot test suite | PASS -- Y (89) confirmed free; B (66) is taken by dbg_toggle_telemetry_hud | test log |
| Tab -> Y interactive playtest | Manual: NOT RUN locally (headless smoke only) | PENDING live Pages deploy | -- |

## Issues encountered
1. KEY_B (66) collision with dbg_toggle_telemetry_hud -- fixed by using KEY_Y (89).
2. CombatCameraDirector bundled in previous commit -- stripped in this cleanup pass per delivery rules.
3. Web export requires --out outside project dir (godot_ci.py enforces this).
4. build-info.json requires finalize-export step after export (GITHUB_SHA unset locally -- used branch HEAD SHA 8d45f59 as fallback).

## Report to Chief

Chief --

Everything local is green. Here is the honest state and my questions.

### What passed
- 742 Godot tests, 0 failed
- Web export: 38 MiB, PCK contains body_flicker_demo.gdc and all 10 VFX PNGs confirmed packed (visible in savepack log)
- Browser smoke: 11/11 PASS, game loads, renders, responds to input, no GDScript errors in console
- All 18 required file paths present and correct

### What is still pending
The one thing I cannot do from this machine without you merging and the Pages CI running:
- Open https://kiotdstudios.github.io/shinobi-rush/, press Tab, press Y, confirm the effect plays

I cannot claim DONE without that. Status stays REVIEW until you or Kiro confirms the live build.

### Camera director separation
I stripped combat_camera_director.gd from this PR as you directed. The Y-key flicker demo works without it. When orcha/dynamic-combat-camera merges separately, I will add a one-line CombatCameraDirector.notify(JUTSU) call back into flicker_demo() -- it is already noted in a TODO comment. No action needed from you on that now.

### Four questions before I expand to 8 directions

1. Does the in-game SE proof read as Body Flicker (extreme speed, not teleport)?
   Specifically: departure burst fast enough? Travel streak readable? Arrival skid convincing?

2. Is 56px SE travel distance right at close-camera zoom (~1.17x)? That is about 66 screen pixels.
   Too short, too long, or correct?

3. Art path for 8-direction set:
   a. Keep procedural silhouettes (free, consistent, fast)
   b. PixelLab API for proper pixel-art frames (needs your budget approval before I spend anything)
   c. Split with Codex -- Codex draws character departure/arrival key poses, Orcha handles speed-lines/dust

4. Timing: 417ms total (10f at 24fps). Is that the right feel or should I trim departure/arrival frames?

### Concern I want to flag
The visual-only prototype does not move the CharacterBody2D. When the ninja "reappears" 56px SE from where they were, the collision body is still at the origin. You will feel a disconnect between where the ninja looks and where input registers. This is labeled and intentional for the demo gate. If the disconnect makes it hard to evaluate the visual, let me know and I will add a temporary position snap (still no production mechanic, just making the demo clearer for review).

Ready for your call. PR is open.

-- Orcha
