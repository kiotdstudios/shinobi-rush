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
Use the [Codex Order 01 specification](../../orders/Codex/order_01.md) for 128×128 RGBA player frames, eight-direction coverage, purposeful 24 fps animation, aligned equippable layers, independent VFX and Web performance validation. Extended poses may use larger canvases without scaling the character.


## Owner revision — PixelLab skill review and art scale
Codex may use its own proven art-generation skills; **review PixelLab API skills and existing credentials first** and use PixelLab when advantageous, not by default for every asset. Sprite frame size is locked at 128×128 (see the decision below and [orders/README.md](../../orders/README.md)); test at actual gameplay zoom before bulk animation generation. See [revised art workflow](./PIXELLAB_API_ART_PIPELINE.md). This owner revision supersedes earlier mandatory-PixelLab wording.


## FINAL OWNER DECISION — Production sprite frame size (2026-10-18)
**LOCKED: All standard production character sprite frames MUST be 128×128 pixels, RGBA with transparency.** This overrides any earlier 64×64 vs 128×128 evaluation or scale-approval requirement in this file or linked orders. Do not create 64×64 production character sprites. Legacy 64×64 artwork may be retained as reference only. Larger canvases may be used for attacks/VFX extending outside the base frame, but keep the character's world-space/body scale, proportions, foot anchor and alignment consistent. Maintain eight-direction animation targets and premium fluid motion. PixelLab remains optional after mandatory skill/API review as separately documented.


## OWNER-APPROVED GAMEPLAY CAMERA FRAMING — 2026-10-19

**Status: LOCKED visual composition target; numerical Camera2D zoom and projection geometry remain subject to measured in-engine approval.** This supersedes the prior preference for the old wide arena framing where it conflicts with the new owner-supplied close-combat reference. It does not change the 128×128 native sprite-frame requirement or the approved MVP route topology.

- **Reference authority:** The owner's 2026-10-19 close-up faux-isometric shrine combat screenshot shared in conversation is the target for **camera distance, player/enemy prominence, relative architectural scale, and visual density**. It is a framing reference, not permission to copy its shrine map, characters, insignia, or combat HUD verbatim. Keep Kōsen's original mountain/three-spire visual identity and Codex's approved player design.
- **Player framing:** Aim for the player standing figure to occupy approximately **16–19% of viewport height**, measured from visible head to feet at the normal gameplay camera zoom. This is a provisional image-based comparison target, not an exact pixel measurement or a final engine constant. At 720 px viewport height this corresponds to about **115–137 screen pixels**; validate with the actual approved Codex sprite rather than assuming the 128 px frame equals character height.
- **Camera behavior:** Fixed three-quarter faux-isometric orientation; Camera2D follows the player smoothly across a continuous, larger-than-viewport world. Show the **immediate combat space** and nearby obstacles rather than fitting an entire village or map in view. Do not zoom out to reveal all authored paths.
- **Relative scale:** Keep player, Basic Bandit, Heavy Bandit, doors, stairs, walls, bridges, trees, and nearby props at coherent human-scale proportions; Heavy Bandit must read as heavier/larger. Preserve crisp nearest-neighbor pixel art, clear attack telegraphs, visible foot anchors, 2D collisions, and correct Y-sort/occlusion.
- **Camera conflict resolution:** Existing WorldScale.CAMERA_BASE_ZOOM = 1 / 2.25 and prior wide-camera PR are prototype baselines, **not locked owner-approved final gameplay framing**. Aki must coordinate with Kiro before modifying camera or occlusion code. Use a configurable camera preset or isolated comparison scene; do not overwrite Kiro's active work.
- **First acceptance gate:** Before mass-producing PixelLab village/forest art or building the full Kōsen map, create a **small playable Godot camera-and-scale validation scene** with actual Codex player art when committed, one Basic Bandit, a Kōsen gate segment, and representative walls/props. Show a side-by-side **1280×720** gameplay screenshot against the owner's reference, accounting for the reference's different aspect ratio. Report measured screen-space standing height, viewport percentage, visible world rectangle, Camera2D zoom, and representative occlusion tests. Provide a browser preview if deployment is available. **Owner approves framing before large-scale art production.**
- **Map authority unchanged:** world/maps/MVP_WORLD_MAP.md remains authoritative: start outside Kōsen Gate; Forest A and B both accessible immediately; both forks; Forest A dead-end clearing; direct A-fork ↔ B-fork traversable connection; Forest C and neighboring village excluded from MVP.
