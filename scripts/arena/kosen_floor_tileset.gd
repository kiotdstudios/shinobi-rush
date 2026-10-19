class_name KosenFloorTileset
extends RefCounted
## Builds the Kosen courtyard floor TileSet in code (no hand-authored .tres): one small,
## reusable isometric tile set covering every variant category the ground-tileset order asked
## for. Source art: assets/environment/kosen_courtyard/floor_tiles/ (PixelLab create_tiles_pro,
## squashed from the tool's native 1:1 top-down square diamond to the game's 2:1 isometric
## ratio so it matches WorldScale's diamond grid convention).
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
	"floor_base_a.png",           # 0 - base stone floor
	"floor_base_b.png",           # 1 - base stone floor, alt mortar tone
	"floor_alt_herringbone.png",  # 2 - alternate stone texture (herringbone laid)
	"floor_cracked.png",          # 3 - cracked / weathered stone
	"floor_dirt_stone.png",       # 4 - dirt-to-stone transition
	"floor_dirt.png",             # 5 - packed dirt
	"floor_decor_a.png",          # 6 - decorative detail (gold cloud inlay)
	"floor_decor_b.png",          # 7 - decorative detail, alt motif
	"floor_edge.png",             # 8 - worn lighter edge (one side), perimeter ring
	"floor_corner.png",           # 9 - worn lighter corner (two sides), perimeter corners
]

const EDGE_SOURCE_ID := 8
const CORNER_SOURCE_ID := 9

## Weighted picks for interior (non-perimeter) cells, aligned to ALL_FILES[0..7]. Base/alt
## textures dominate; cracked/dirt/decorative are sprinkled in so they read as variation, not
## the main pattern.
const INTERIOR_WEIGHTS: Array[int] = [10, 10, 6, 3, 2, 1, 1, 1]


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
