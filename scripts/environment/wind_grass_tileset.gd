class_name WindGrassTileset
extends RefCounted
const TILE_SIZE := Vector2i(72, 36)
const DIR := "res://assets/environment/kosen_courtyard/grass/tiles/"
const ROLES: Array[String] = ["corner_top", "edge_ne", "corner_right", "edge_nw", "center", "edge_se", "corner_left", "edge_sw", "corner_bottom"]

static func role_at(x: int, y: int, width: int, height: int) -> int:
	if y == 0:
		return 0 if x == 0 else 2 if x == width - 1 else 1
	if y == height - 1:
		return 6 if x == 0 else 8 if x == width - 1 else 7
	return 3 if x == 0 else 5 if x == width - 1 else 4

static func _base() -> TileSet:
	var set := TileSet.new()
	set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	set.tile_size = TILE_SIZE
	return set

static func _source(set: TileSet, path: String, size: Vector2i, origin: Vector2i, index: int, wind: ShaderMaterial) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(path) as Texture2D
	source.texture_region_size = size
	source.create_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = origin
	data.y_sort_origin = 0
	data.material = wind
	set.add_source(source, index)

static func build_ground(wind: ShaderMaterial = null) -> TileSet:
	var set := _base()
	for i in ROLES.size():
		_source(set, DIR + "grass9_" + ROLES[i] + ".png", Vector2i(112, 112), Vector2i(0, 28), i, wind)
	return set

static func build_tall(wind: ShaderMaterial = null) -> TileSet:
	var set := _base()
	for i in 4:
		_source(set, DIR + "grass_tall_%02d.png" % i, Vector2i(112, 160), Vector2i(0, 56), i, wind)
	return set
