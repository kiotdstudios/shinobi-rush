# Combat effects V1 — provisional art handoff

Independent 128×128 RGBA frames, pivot [64,64], no baked character or floor shadow. See combat_vfx.json for exact paths, counts, FPS and hashes. Source game-pack manifests preserve original cropped-atlas offsets. The build script uses a constant translation only, without scaling, smoothing or alpha conversion.

- sword_trail_light: 8 frames at24 FPS, 333ms.
- sword_trail_heavy: 8 frames at24 FPS, 333ms; broader committed arc.
- hit_spark: 4 frames at24 FPS, 167ms, also reusable for enemy contact.

Timing remains a visual proposal pending Aki's combat configuration. Gameplay chooses trigger, speed and contact socket. Trails attach at the sword-hand socket; spark attaches at the world contact point. Effect pivots are not character foot anchors. Apply facing and placement independently; do not stretch the player sprite or modify camera zoom to fit effects. Stop after final frame; the browser inspection page adds a review pause only.

PixelLab VFX workbench was used to design and render these effects; separate light/heavy/slash and spark parts, silver-white and warm spark palettes. No character attack frames are supplied by this VFX checkpoint. Parry/guard-break effects belong in the follow-up defensive PR.

Preview: ../../characters/player/previews/combat-v1/index.html (serve repository over HTTP).
