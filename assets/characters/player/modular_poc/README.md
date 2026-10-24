# Shared-body sword art proof

One approved player, SE direction, three-hit combo, two separate one-handed swords. The24 weaponless128×128 RGBA body frames are shared by both swords. Existing847 movement frames and player_128.manifest.json are unchanged. This is opt-in art data; Aki owns runtime attachment/combat integration.

- `modular_poc.json`: per-frame body path/hash, right-hand grip, clockwise orientation, weapon draw order, hand occlusion region, foot anchor and timing recommendations.
- `body/`: one24-frame weaponless combo; no sword pixels or floor shadow.
- `weapons/`: curved katana and straight sword,64×64 transparent master textures at the same native pixel scale. Both grip pivots are[14,32], blade local+X.
- `baked_reference/`: the completed24-frame fully drawn katana comparison, including the finished8-frame sword finisher. Retain for fallback/comparison during migration.
- `../../../vfx/combat/`: independent light/heavy trails and hit spark, with timing metadata.
- `../previews/modular-weapon-poc/index.html`: synchronized browser comparison with clock, frame scrub, speed, anchors, separate trails and game-size/2× inspection.
- `../previews/modular-weapon-poc/`: individual half-speed GIFs and comparison GIF/contact sheet for phone review.

Body canvas stays128×128, foot anchor[64,116], body scale104px. Inspection composites use192×192 to show independent weapon overhang without shrinking the character. Rotation uses nearest-pixel sampling. No weapon-dependent body replacement is performed.

Timing is a proposal:24FPS source, default review0.5×. Contact/active/transition/cancel indices are zero-based and await Aki's gameplay configuration. Browser effects are an art demonstration; this is not evidence of gameplay hitbox/movement integration. Expansion remains gated on alignment, fluidity and visual-quality acceptance.

See INTEGRATION_NOTES.md and orders/Aki/2026-10-19-modular-weapon-system-poc.md for the engineering handoff.
