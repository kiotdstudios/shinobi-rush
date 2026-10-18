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


## Mandatory PixelLab API art-generation policy
**All new generated pixel-art assets for Shinobi Rush must be created through the PixelLab API** (characters, directional sprites, animations, equipment, enemies, tiles, props, environment art, UI pixel art and pixel VFX). Read [PixelLab API art pipeline](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md) before art work. Codex owns generation; other agents request assets from Codex rather than using alternative generators. Manual pixel cleanup, sprite compositing, shaders, particle systems, and programmatic Godot integration are permitted post-processing—not substitutes for PixelLab-generated source art. Never embed or commit API keys. If PixelLab API credentials, features, quotas or outputs are unavailable, report BLOCKED; do not silently switch generators.
