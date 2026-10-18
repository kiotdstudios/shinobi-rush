# Shinobi Rush — Camera and Art Direction (Authoritative)

## Camera projection — LOCKED intent
Shinobi Rush is a **2D three-quarter overhead, faux-isometric action RPG**. The camera looks diagonally **down at the ground**, showing the top and front/side surfaces of objects. This is **not** a side-view platformer, profile fighter, eye-level view, first-person view, or strictly overhead bird's-eye view. It is **not** a true perspective 3D camera.

**Do not arbitrarily assume a mathematically exact 30° or 45° projection.** The exact apparent elevation, diamond tile ratio, sprite foreshortening, zoom, and pixel scale are **pending an in-engine visual test and owner approval**. Maintain a coherent three-quarter look in all prototype art, and present a small angle/style comparison if an irreversible asset production decision depends on precise camera geometry.

## What Codex must draw
- **Character:** view from above and diagonally, with top of hair/head, shoulders and feet visible. In south-facing gameplay poses, show face/chest and upper planes of shoulders; in north-facing poses, show back/head and shoulders; in east/west, show side planes with visible top surfaces. Avoid pure orthographic front/side character-sheet perspective for in-game sprites.
- **Directional movement:** aim for 8-direction readability in gameplay (N, NE, E, SE, S, SW, W, NW). Produce at least N/S/E/W initially and define how diagonals are represented; do not assume flipping all frames is always visually correct.
- **Animation:** idle, normal run, **distinct R1 ninja sprint with forward-leaning torso and both arms back**, dodge, jump, melee, hit. Keep feet planted on a consistent ground anchor and preserve facing during motion. Animations should work from the elevated three-quarter camera.
- **Environment:** ground planes visible from above, building/wall tops and front-facing vertical surfaces consistently drawn; no side-scrolling horizons. Props and trees use a ground contact point for Y sorting and occlusion.
- **VFX:** impact rings and ground shadows lie on the ground plane; airborne effects rise visually above the foot anchor. Maintain consistent directional attack arcs.
- **Lighting:** coherent directional light and shadows across all assets, without painting inconsistent camera perspectives into sprite frames.
- **Reference image:** `assets/characters/player/references/baseline_turnaround.png` is the **appearance** reference (front/side/back neutral turnaround), **not the gameplay camera angle**. Translate its exact character design faithfully into new three-quarter gameplay sprites. Never merely paste the orthographic turnaround into the game.

## Godot implementation coordination
Use Godot 4 2D rendering with a fixed-angle Camera2D; align 2D ground movement, depth/Y sorting, character feet anchors, collisions, and TileMapLayer art. Validate overlap when walking behind/in front of props. Confirm camera/scale with gameplay owner before generating large asset batches.

## Art acceptance checklist
1. Show Codex's sprite alongside the baseline PNG and a representative in-game mockup.
2. Test north/south/east/west and diagonal-facing behavior at actual gameplay zoom.
3. Test sprite/prop Y-sorting and ground-contact anchors.
4. Test normal run versus R1 ninja sprint from this camera.
5. Reject art that accidentally looks side-scrolling, straight-on orthographic, or directly top-down.

**Status:** Camera style and three-quarter visual intent are locked; exact numeric angle, tile geometry, and zoom remain prototype-tunable. **Player art frame size is locked to 128×128 RGBA with approximately 100–112 px standing character height for Order 01.**


## Character animation / equipment standard
Use the [Codex Order 01 specification](../../orders/Codex/order_01.md) for 128×128 player frames, eight-direction coverage, purposeful 24 fps animation, aligned equippable layers, independent VFX and Web performance validation. Extended poses may use larger canvases without scaling the character.
