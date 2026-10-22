class_name KosenFloorTileset
extends RefCounted
## Builds the Kosen courtyard floor TileSet in code (no hand-authored .tres): one small,
## reusable isometric tile set covering every variant category the ground-tileset order asked
## for. Source art: assets/environment/kosen_courtyard/floor_tiles/, generated with PixelLab
## create_tiles_pro (isometric, 64x64 slabs) from a text prompt matching the owner's stone floor
## mockup palette; only each slab's flat top face is kept, resized to the game's 72x36 diamond.
##
## Deterministic variation: pick_interior_source_id() is a pure function of the cell
## coordinate (hash, not randf()), so the same arena always paints the same way across runs —
## "random-looking" without being non-reproducible.

## Native per-tile footprint. Half the linear size of the old repeated-block tile (144x72),
## i.e. ~4x the tile density per unit area: this is what makes the ground read as fine paving
## instead of a few giant slabs. Tune here if the owner wants it finer/coarser later.
const TILE_SIZE := Vector2i(72, 36)

const TILE_DIR := "res://assets/environment/kosen_courtyard/floor_tiles/"

## Source order fixes each file's source_id (position in this array == source_id), so callers
## can address sources by the named constants below without a separate lookup table.
const ALL_FILES: Array[String] = [
	"floor_slate_crack_a.png",           # 0 - dark slate, hairline cracks
	"floor_slate_crack_b.png",           # 1 - dark slate, hairline cracks, alt
	"floor_slate_mixed_a.png",           # 2 - mixed cool/warm mottling
	"floor_slate_mixed_b.png",           # 3 - mixed cool/warm mottling, alt
	"floor_slate_warm_a.png",            # 4 - warm amber weathering
	"floor_slate_warm_b.png",            # 5 - warm amber weathering, alt
	"floor_slate_light_a.png",           # 6 - lighter cooler worn slate
	"floor_slate_light_b.png",           # 7 - lighter cooler worn slate, alt
	"floor_slate_dark_a.png",            # 8 - dark worn slate
	"floor_slate_lichen_a.png",          # 9 - lichen / frost patches (rare)
	"floor_slate_goldcrack_a.png",       # 10 - gold-inlay cracks (rare)
	"floor_rune_cloud.png",              # 11 - gold cloud-rune medallion (very rare)
	"floor_slate_dark_b.png",            # 12 - darker worn edge (perimeter ring)
	"floor_slate_dark_a.png",            # 13 - darker worn corner (perimeter corners)
]

const EDGE_SOURCE_ID := 12
const CORNER_SOURCE_ID := 13

## Weighted picks for interior (non-perimeter) cells, aligned to ALL_FILES[0..11]. Base/alt
## textures dominate; cracked/dirt/decorative are sprinkled in so they read as variation, not
## the main pattern.
const INTERIOR_WEIGHTS: Array[int] = [48, 48, 9, 9, 6, 6, 3, 3, 42, 3, 6, 1]


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE_SIZE
	for i in ALL_FILES.size():
		var tex := load(TILE_DIR + ALL_FILES[i]) as Texture2D
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = TILE_SIZE
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, i)
	return ts


## Deterministic pseudo-random interior variant for cell (i, j): same input, same output, every
## run — "avoid obvious repetition" without the ground changing shape from one playtest to the
## next (which would make bug reports about specific tiles impossible to reproduce).
## Godot's built-in hash(Vector2i) correlates along diagonals (visible banding on a grid this
## regular); this is a standalone integer mixing hash (large-prime multiply + xor-shift, same
## family as "squirrel noise") chosen for a clean avalanche so adjacent cells do not cluster.
static func _mix_hash(i: int, j: int) -> int:
	var h := i * 0x27d4eb2d + j * 0x9e3779b1
	h = (h ^ (h >> 15)) * 0x85ebca6b
	h = (h ^ (h >> 13)) * 0xc2b2ae35
	h = h ^ (h >> 16)
	return absi(h)


static func pick_interior_source_id(i: int, j: int) -> int:
	var total := 0
	for w in INTERIOR_WEIGHTS:
		total += w
	var r := _mix_hash(i, j) % total
	var acc := 0
	for idx in INTERIOR_WEIGHTS.size():
		acc += INTERIOR_WEIGHTS[idx]
		if r < acc:
			return idx
	return 0
