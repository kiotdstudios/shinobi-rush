# Source provenance — ryo pouch

Date: 2026-10-26. Generator: built-in image_gen. PixelLab documentation/access reviewed; PixelLab generation not used.

- `reference.jpg`: owner-supplied classic pouch mockup; locks brown leather, gathered mouth, red cord and gold square-hole medallion.
- `idle-raw.png`: 4×4 idle/sway generation using that reference. Sixteen distinct small pleat/cord/medallion poses, stable lower center, same three-quarter front/SE view. Body only, solid magenta matte; no floor/shadow/glow.
- `glow-raw.png`: independent 4×3 golden aura loop, same center and scale, broken warm-gold wisps, small star accents, no pouch. Solid magenta matte.
- `ember-raw.png`: independent 4×3 sparse golden sparkle loop around an empty central pouch region. Yellow-white stars and gold motes. Solid magenta matte.
- `collect-raw.png`: 4×2 collection body, referencing the accepted idle design: neutral, squash, rebound/stretch, shrink, tiny pouch, clear. The final generated cell is empty and is deliberately retained as the explicit disappear frame.

`scripts/art/build_ryo_pouch.py` performs deterministic chroma-key cleanup, gold-only matte spill decontamination, shared scale, stable registration, PNG extraction, contact sheets and data-only Godot exports. No new sprite shapes are drawn by code. Floor light is a documented projection of the generated aura. `preview_ryo_pouch.py` composites the finished art to show the existing pickup motion; it is not a gameplay implementation.
