---
name: three-quarter-game-art
description: Create, verify, and integrate Shinobi Rush three-quarter faux-isometric sprites, animations, tiles, props, and VFX from approved visual references.
---
# Three-quarter game art

Read [camera and art direction](../../docs/visuals/CAMERA_AND_ART_DIRECTION.md) and the approved `assets/characters/player/references/baseline_turnaround.png` before generating player sprites.

1. Preserve character identity from the turnaround, but redraw in elevated three-quarter gameplay perspective.
2. Do not treat the turnaround's flat front/side/back views as gameplay poses. No mask, cape, sword, or sword strap.
3. Separate normal locomotion from R1 Naruto-inspired arms-back forward-leaning ninja sprint. Create original frames only.
4. Define sprite canvas, frame dimensions, direction naming, animation FPS, ground/feet anchor, palette, alpha channel, and import manifest. Exact numerical sprite resolution and projection remain provisional pending gameplay review.
5. Preview N/S/E/W and diagonals at gameplay zoom; test clipping, sprite foot alignment, depth overlap, attack silhouettes, and frame loop continuity.
6. Include art source files where practical, PNG exports, manifest, before/after visual previews, test evidence, and integration notes.
7. Coordinate runtime integration; deploy to live browser test build after checks. Write a job report including questions and issues.
