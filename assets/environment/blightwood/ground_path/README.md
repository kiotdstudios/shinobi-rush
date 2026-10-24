# Blightwood ground/path — nine roles

Worn olive-gray earth and fine slate gravel, using the **exact 22 RGB colors extracted from all thirteen existing grass PNGs**, including the tall silvergrass. Fully opaque painted pixels and transparent diamond surroundings; no interpolation.

Nine 72×36 PNGs and a 216×108 atlas. Logical tile size72×36, origin36,18, nearest filtering. Atlas roles, row-major:

| | | |
|---|---|---|
| top corner | NE edge | right corner |
| NW edge | center | SE edge |
| left corner | SW edge | bottom corner |

These form a rectangular patch in the existing isometric diamond grid. Center/edge roles can repeat for longer paths; repeated texture joins are organic and **not guaranteed pixel-identical**. The original3×3 assembled patch samples one continuous generated surface.

Original source: built-in image generation, excluded from Godot import under source/. PixelLab account/API reviewed; no paid PixelLab request for this set. Export script constrains the texture to the exact grass palette and samples the fixed isometric footprint without bilinear filtering. Palette source hashes and tile hashes are in ground-nine.art.json.

Approved art is available under World Builder > Ground / paths, with a dedicated checkbox filter. Place, select, drag, erase/delete and save/reload use existing controls. Tiles snap to72x36 diamond centers and render over the floor beneath grass/actors, without collisions. Existing ground and saved layouts are preserved. Rebuild and validate with `python docs/visuals/blightwood-ground-nine/export.py`; native proof is alongside the previews. See contact-sheet.png and assembled-preview.png in that folder.
