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

## Source order fixes each file's source_id (position in this array == source_id).
## Owner-approved 9-slice family (center + 4 edges + 4 corners, one consistent dark-slate
## look) plus a few plain/cracked/mossy centre variants so the interior does not repeat.
const ALL_FILES: Array[String] = [
	"floor9_center.png",         # 0  centre floor
	"floor9_center_b.png",       # 1  centre floor, alt
	"floor9_cracked_a.png",      # 2  centre, cracked
	"floor9_cracked_b.png",      # 3  centre, heavily cracked
	"floor9_moss_a.png",         # 4  centre, mossy
	"floor9_edge_nw.png",        # 5  lip on the upper-left side
	"floor9_edge_ne.png",        # 6  lip on the upper-right side
	"floor9_edge_se.png",        # 7  lip on the lower-right side
	"floor9_edge_sw.png",        # 8  lip on the lower-left side
	"floor9_corner_top.png",     # 9  lip on both upper sides (top vertex)
	"floor9_corner_right.png",   # 10 lip on both right sides (right vertex)
	"floor9_corner_bottom.png",  # 11 lip on both lower sides (bottom vertex)
	"floor9_corner_left.png",    # 12 lip on both left sides (left vertex)
]

const EDGE_NW := 5
const EDGE_NE := 6
const EDGE_SE := 7
const EDGE_SW := 8
const CORNER_TOP := 9
const CORNER_RIGHT := 10
const CORNER_BOTTOM := 11
const CORNER_LEFT := 12

## Weighted picks for interior cells, aligned to ALL_FILES[0..4].
const INTERIOR_WEIGHTS: Array[int] = [40, 40, 10, 4, 6]


## Rim tile for a border cell, from which sides of the ground rectangle it touches. A screen-space
## rectangle's top border reads as the diamond's upper rim, so it gets the top-vertex piece, and
## so on; the four rectangle corners get the single-side edge pieces.
static func ring_source_id(near_left: bool, near_right: bool, near_top: bool, near_bottom: bool) -> int:
	if near_top and near_left:
		return EDGE_NW
	if near_top and near_right:
		return EDGE_NE
	if near_bottom and near_right:
		return EDGE_SE
	if near_bottom and near_left:
		return EDGE_SW
	if near_top:
		return CORNER_TOP
	if near_bottom:
		return CORNER_BOTTOM
	if near_left:
		return CORNER_LEFT
	return CORNER_RIGHT


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
