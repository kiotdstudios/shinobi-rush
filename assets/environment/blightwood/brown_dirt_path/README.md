# Brown / tan path earth

Art-only delivery. **NOT LIVE — awaiting builder integration.** Existing green `ground9_*` and grass assets are untouched.

Extract the ZIP into `assets/environment/blightwood/brown_dirt_path/` so manifest paths resolve.

Native logical cell: 72×36 diamond. PNG canvas: 112×112, origin **(56,84)**, exactly matching the existing `grass9_*` registration. Every diamond pixel is opaque; only surroundings and selected grass overhang are transparent. Use nearest filtering and no mipmaps. No collision or vertical extrusion.

`tiles/dirt9_*` provides the same nine role names and role order as grass. Brown center reaches connected edges; only exposed sides retain the actual approved grass fringe. This avoids green grid lines through a connected path.

`tiles/dirt16_00..15` supplies all edge combinations for narrower trails, bends, end caps and isolated patches. A set bit means **grass border on that side**, not a connected dirt neighbour:

| Side | Bit | Grid neighbour |
| --- | --- | --- |
| NE | 1 | (36,-18) |
| NW | 2 | (-36,-18) |
| SE | 4 | (36,18) |
| SW | 8 | (-36,18) |

Set each bit when that neighbour is not brown path. Mask 0 is connected dirt on all sides; mask 15 is an isolated dirt patch. Nine-role aliases: top=3, NE=1, right=5, NW=2, center=0, SE=4, left=10, SW=8, bottom=12. Additional masks handle the combinations a nine-piece set cannot represent. These are edge masks, not the existing shoreline corner-bit convention.

Ground remains a full cell even where grass visually overlaps dirt. Do not use grass alpha to punch holes into the ground. Lay on the existing lattice, sorting by ground position. Do not clip the whole PNG to 72×36 or place its origin at (36,18): the padded grass fringe uses the existing 112×112 canvas.

The soil material comes from built-in image generation; vegetation pixels come from the exact current grass PNGs, recorded with SHA256 in the manifest. Deterministic palette reduction, nearest sampling, periodic boundary preparation and compositing are in `scripts/art/build_brown_dirt_path.py`. No paid PixelLab generation was used. Opposite soil boundary texels are identical; no blurred transition ramp is used.

`dirt-nine-atlas.png` has 112×112 cells in the grass role order. The manifest records all 16 canonical PNGs and nine aliases. Preview and ZIP are in `docs/visuals/brown-dirt-path/`.
