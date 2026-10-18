---
name: three-quarter-game-art
description: Create, verify, and integrate Shinobi Rush three-quarter faux-isometric sprites, animations, tiles, props, and VFX from approved visual references.
---
# Three-quarter game art

Read [camera and art direction](../../docs/visuals/CAMERA_AND_ART_DIRECTION.md) and the approved `assets/characters/player/references/baseline_turnaround.png` before generating player sprites.

1. Preserve character identity from the turnaround, but redraw in elevated three-quarter gameplay perspective.
2. Do not treat the turnaround's flat front/side/back views as gameplay poses. No mask, cape, sword, or sword strap.
3. Separate normal locomotion from R1 Naruto-inspired arms-back forward-leaning ninja sprint. Create original frames only.
4. Define sprite canvas, frame dimensions, direction naming, animation FPS, ground/feet anchor, palette, alpha channel, and import manifest. For Order 01 the player sprite frame is 128×128 RGBA, approximately 100–112 px standing height, fixed feet anchor; the numeric camera projection remains prototype-tunable.
5. Preview N/S/E/W and diagonals at gameplay zoom; test clipping, sprite foot alignment, depth overlap, attack silhouettes, and frame loop continuity.
6. Include art source files where practical, PNG exports, manifest, before/after visual previews, test evidence, and integration notes.
7. Coordinate runtime integration; deploy to live browser test build after checks. Write a job report including questions and issues.


Use [Order 01 fluidity and equipment standards](../../orders/Codex/order_01.md): eight directions, 24 fps authored animation baseline, meaningful in-betweens, layered equipment sockets, independent VFX, and Web performance testing.





## Owner revision — PixelLab skill review and art scale
Codex may use its own proven art-generation skills; **review PixelLab API skills and existing credentials first** and use PixelLab when advantageous, not by default for every asset. Sprite frame size is locked at 128×128 (see the FINAL OWNER DECISION below); test at actual gameplay zoom before bulk animation generation. See [revised art workflow](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md). This owner revision supersedes earlier mandatory-PixelLab wording.


## FINAL OWNER DECISION — Production sprite frame size (2026-10-18)
**LOCKED: All standard production character sprite frames MUST be 128×128 pixels, RGBA with transparency.** This overrides any earlier 64×64 vs 128×128 evaluation or scale-approval requirement in this file or linked orders. Do not create 64×64 production character sprites. Legacy 64×64 artwork may be retained as reference only. Larger canvases may be used for attacks/VFX extending outside the base frame, but keep the character's world-space/body scale, proportions, foot anchor and alignment consistent. Maintain eight-direction animation targets and premium fluid motion. PixelLab remains optional after mandatory skill/API review as separately documented.
