# Ryo pouch — art and animation handoff

Owner request: **art and animations only; Aki owns the backend.** This pack does not register a pickup, award currency, change inventory/spawns, edit controllers or add anything to the live scene.

The classic pouch follows the supplied mockup: warm chestnut leather, gathered open mouth, red cord, hanging gold square-hole medallion. Facing is elevated three-quarter front/SE, matching the existing nondirectional pickup presentation.

## Assets
All paths below are relative to `assets/pickups/ryo_pouch/`. All images are transparent RGBA; use nearest filtering.

| Layer | Frames | Canvas / centered origin | Timing | Blend |
| --- | --- | --- | --- | --- |
| Idle body `gourd_00.png` … `gourd_15.png` | 16 unique | 128×128 / (64,64) | 14 FPS loop | Normal |
| Gold aura `glow_00.png` … `glow_11.png` | 12 unique | 96×96 / (48,48) | 12 FPS loop | Additive |
| Sparkles `ember_00.png` … `ember_11.png` | 12 unique | 96×96 / (48,48) | 12 FPS ping-pong; 22 playback frames | Additive |
| Floor light `floor_glow_00.png` … `floor_glow_11.png` | 12 derived | 96×96 / (48,48) | 12 FPS loop | Additive |
| Collect body `collect_00.png` … `collect_07.png` | 7 visible poses + intentional terminal clear | 128×128 / (64,64) | Variable durations, one shot | Normal |

The idle files retain the generic loader's existing `gourd_XX` prefix for compatibility; the pixels depict the ryo pouch. `icon.png` is the first idle pose. Four `*-sheet.png` atlases support bulk import. Individual frames and `animations.tres` are sufficient for Godot. `additive.tres` is a ready-to-use unshaded additive material for the three light/particle layers.

Idle body baseline is y104, with 78–80px silhouette height. Render body at scale 1 to match the existing 75px health-gourd body. The supplied mockup's “32×32” label is reference layout text; production export retains the project's more detailed 128px canvas.

## Existing pickup presentation match
- World root stays on the ground. Body/aura/sparks hover at y−56.
- Add a whole-pixel ±4px bob at 2.3 radians/sec, as `HealthGourd` currently does. Authored idle motion is only the leather, cord and medallion sway; it does not contain the external bob.
- Aura uses the existing 1.25–1.55 scale breath, 3.1 radians/sec pulse, 0.35 radians/sec rotation. Use gold/yellow-white coloration. No blue tint is needed.
- Optional floor-light frames sit at the world root; their projected 92×24 footprint matches the current 46×12-radius pool. They are derived from the generated aura and remain separate from the pouch.

## Collection timing
The visual phases match the current `GourdPickupFx` reference: contact 0–80ms; rebound/burst 80–180ms; warp toward the player's **current chest** 180–350ms; absorb flash 350–450ms; tail to 550ms. Existing floating-label duration is 1.25s; Aki supplies its currency text/value.

Authored collect frame durations are **40, 40, 50, 50, 50, 50, 70, 50ms**. Frame 7 is intentionally completely transparent, clearing the body at 350ms; the resource's total duration is 400ms including that terminal hold. Keep glow/sparks alive through the remaining absorption tail. Body frame 6 is a tiny pouch before disappearance.

**Avoid applying the squash/shrink twice.** With the authored collect track, animate world position toward the live chest while keeping body scale at 1; squash/stretch/shrink are already in the frames. If retaining the existing procedural GourdPickupFx transforms unchanged, use idle body art for that path and treat the authored collect track as the alternate art clip. The two presentation modes share the same phase/contact timing.

Collection travel is not baked into the sprites, so Aki can track a moving player. Currency amount, collection eligibility, bag rules, spawning, respawn, sound playback and HUD changes are intentionally left to Aki.

## Previews and QA
`normal.gif` and `half-speed.gif` are art-only composites at 1× and 2× detail, using the accepted pickup motion and the real exported assets. Their four-second reset is a review loop, not a gameplay respawn rule. PNG contact sheets identify every frame, including terminal clear. `asset-qa.json` records uniqueness, dimensions, anchors, bounds and clipping. `import-validation.json` records actual Godot loading.

Generation: built-in image_gen, using the owner mockup as identity/style reference. PixelLab MCP documentation and configured access were reviewed; no PixelLab generation was used. Scripts only key/decontaminate the magenta matte, uniformly scale/register source images, export textures/resources and composite previews.
