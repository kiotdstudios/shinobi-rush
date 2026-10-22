# Fire pillar (stone lantern)

Owner 2026-10-22: "from this mockup can you make this little fire pillar thingy, need a very
detailed fire animation as always max frames to get the quality matching the grass." Matches the
small stone-lantern-with-embers reference crop from the shrine mockup screenshot.

## Runtime

- `pillar_base.png`: static stone lantern body, 160x224 RGBA, foot anchor `[80,216]`, embers baked
  into the window/bowl. `bowl_anchor` in `fire_pillar.art.json` is measured (not guessed) from the
  actual warm-pixel region of this texture -- the bottom of that region, where the flame's base
  should visually sit.
- `tiles/flame_00..15.png`: 16 real painted key-pose flame frames, 112x144 RGBA each, shared
  12-color fire palette, foot anchor `[56,140]`. Played as one looping `AnimatedSprite2D` animation
  at 14 fps (see `scripts/environment/fire_pillar.gd`).
- Extra flicker life beyond the 16 painted frames -- a continuously pulsing additive glow halo and a
  slow-rising ember particle stream, both procedural (`FirePillar._make_glow_texture()` /
  `_make_ember_texture()`, no external art) -- is the SAME hybrid philosophy as
  `docs/visuals/wind-grass-nine` (144 shader phases) and `blossom_trees` (96 shader phases): a real
  painted frame set plus continuous procedural richness on top, not a claim of more painted frames
  than actually exist.
- No collision/navigation: purely decorative, same precedent as `WindGrassField`/`BlossomGrove`.
  Placed at `WorldScale.FIRE_PILLAR_POSITIONS` by `FirePillarField` (one node, additive, in
  `scenes/arena/training_arena.tscn`).

## Source and reproduction

Both source images made with built-in image generation (no paid PixelLab generation), preserved
under `source/` (excluded from the Godot import scan via `source/.gdignore`):

- `pillar-raw.png`: the stone lantern, generated on a flat lime-green chroma-key background.
- `flame-grid-raw.png`: a 4x4 grid of 16 distinct flame flicker key poses, generated on a near-white
  background. The model repeatedly drew a small wood/log base under every flame despite explicit
  "no logs" instructions (tried twice) -- removed per-pixel by color saturation (flame colors are
  vivid/saturated, the log's brown is comparatively muddy), not a fixed crop line. An earlier
  fixed-proportion-crop attempt cut several frames down to nothing; see
  `orders/Orcha/2026-10-22-fire-pillar.md` for the full story.

Reproducible with:

```
python docs/visuals/fire-pillar/export_fire_pillar.py
```

See `docs/visuals/fire-pillar/flame-16-contact.png` for the full 16-frame contact sheet.
