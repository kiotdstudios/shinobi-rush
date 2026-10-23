class_name PlacedObjects
extends Node
## The player-editable layer of the arena: trees, walls and decorative grass.
## Solid props block player/bandit navigation; grass is passable. Layouts survive restarts.
## To add a new buildable thing, add ONE row to CATALOG (and an id to CATEGORIES so it shows in the panel).
##   kind "block": a placeholder box (TrainingArena.Block/BlockRear) with `footprint` (w, depth) and `height`.
##   kind "wall":  a pre-drawn isometric wall piece from wall_kit_v2 (art, size, anchor = pixel of the front-bottom-left ground corner, col = ground vector of its collider).
##                 `pos` is that ground corner, snapped to a floor-diamond vertex, so a piece placed at the previous piece's pos + run joins it.
##   kind "tree":  one of the five Codex blossom trees (index into blossom_trees.art.json); solid trunk base only.
const SAVE_PATH := "user://world_builder_layout.json"
## v4 adds editable grass to v3 saves, which list EVERY solid object (starting trees and the arena's placeholder walls included, ids "base_N" = WorldScale.BLOCKS[N]).
## v1 saves only listed additions (so they also get the default trees + walls); v2 saves lacked the walls.
const SAVE_VERSION := 4
const CATALOG := {
	"tree_1": {"label": "Tiered tree", "kind": "tree", "tree": 0},
	"tree_2": {"label": "Windswept tree", "kind": "tree", "tree": 1},
	"tree_3": {"label": "Weeping tree", "kind": "tree", "tree": 2},
	"tree_4": {"label": "Branching tree", "kind": "tree", "tree": 3},
	"tree_5": {"label": "Sparse tree", "kind": "tree", "tree": 4},
	"wall_h": {"label": "Wall (wide)", "kind": "block", "footprint": Vector2(270, 90), "height": 150.0},
	"wall_v": {"label": "Wall (deep)", "kind": "block", "footprint": Vector2(90, 270), "height": 150.0},
	"rock": {"label": "Rock", "kind": "block", "footprint": Vector2(120, 110), "height": 110.0},
	"crate": {"label": "Crate", "kind": "block", "footprint": Vector2(108, 108), "height": 108.0},
	"kit_se_2": {"label": "Wall SE x2", "kind": "wall", "art": "wall_se_2", "size": Vector2(110, 152), "anchor": Vector2(8, 118), "col": Vector2(72, 36)},
	"kit_se_3": {"label": "Wall SE x3", "kind": "wall", "art": "wall_se_3", "size": Vector2(146, 170), "anchor": Vector2(8, 118), "col": Vector2(108, 54)},
	"kit_se_4": {"label": "Wall SE x4", "kind": "wall", "art": "wall_se_4", "size": Vector2(182, 188), "anchor": Vector2(8, 118), "col": Vector2(144, 72)},
	"kit_se_5": {"label": "Wall SE x5", "kind": "wall", "art": "wall_se_5", "size": Vector2(218, 206), "anchor": Vector2(8, 118), "col": Vector2(180, 90)},
	"kit_se_6": {"label": "Wall SE x6", "kind": "wall", "art": "wall_se_6", "size": Vector2(254, 224), "anchor": Vector2(8, 118), "col": Vector2(216, 108)},
	"kit_sw_2": {"label": "Wall SW x2", "kind": "wall", "art": "wall_sw_2", "size": Vector2(110, 152), "anchor": Vector2(102, 118), "col": Vector2(-72, 36)},
	"kit_sw_3": {"label": "Wall SW x3", "kind": "wall", "art": "wall_sw_3", "size": Vector2(146, 170), "anchor": Vector2(138, 118), "col": Vector2(-108, 54)},
	"kit_sw_4": {"label": "Wall SW x4", "kind": "wall", "art": "wall_sw_4", "size": Vector2(182, 188), "anchor": Vector2(174, 118), "col": Vector2(-144, 72)},
	"kit_sw_5": {"label": "Wall SW x5", "kind": "wall", "art": "wall_sw_5", "size": Vector2(218, 206), "anchor": Vector2(210, 118), "col": Vector2(-180, 90)},
	"kit_sw_6": {"label": "Wall SW x6", "kind": "wall", "art": "wall_sw_6", "size": Vector2(254, 224), "anchor": Vector2(246, 118), "col": Vector2(-216, 108)},
	"kit_pillar": {"label": "Pillar", "kind": "wall", "art": "pillar", "size": Vector2(64, 120), "anchor": Vector2(31, 119), "col": Vector2(0, 0)},
	"kit_ruin_se": {"label": "Ruin SE", "kind": "wall", "art": "ruin_se", "size": Vector2(182, 158), "anchor": Vector2(-7, 143), "col": Vector2(144, 72)},
	"kit_ruin_sw": {"label": "Ruin SW", "kind": "wall", "art": "ruin_sw", "size": Vector2(182, 158), "anchor": Vector2(188, 143), "col": Vector2(-144, 72)},
	"grass9_corner_top": {"label": "Corner Top", "kind": "grass", "tall": false},
	"grass9_edge_ne": {"label": "Edge Ne", "kind": "grass", "tall": false},
	"grass9_corner_right": {"label": "Corner Right", "kind": "grass", "tall": false},
	"grass9_edge_nw": {"label": "Edge Nw", "kind": "grass", "tall": false},
	"grass9_center": {"label": "Center", "kind": "grass", "tall": false},
	"grass9_edge_se": {"label": "Edge Se", "kind": "grass", "tall": false},
	"grass9_corner_left": {"label": "Corner Left", "kind": "grass", "tall": false},
	"grass9_edge_sw": {"label": "Edge Sw", "kind": "grass", "tall": false},
	"grass9_corner_bottom": {"label": "Corner Bottom", "kind": "grass", "tall": false},
	"grass_tall_00": {"label": "Tall grass 1", "kind": "grass", "tall": true},
	"grass_tall_01": {"label": "Tall grass 2", "kind": "grass", "tall": true},
	"grass_tall_02": {"label": "Tall grass 3", "kind": "grass", "tall": true},
	"grass_tall_03": {"label": "Tall grass 4", "kind": "grass", "tall": true},
}
## Panel sections: [title, [ids]].
const CATEGORIES := [["Trees", ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]], ["Walls & blocks", ["wall_h", "wall_v", "rock", "crate"]], ["Temple walls", ["kit_se_2", "kit_se_3", "kit_se_4", "kit_se_5", "kit_se_6", "kit_sw_2", "kit_sw_3", "kit_sw_4", "kit_sw_5", "kit_sw_6", "kit_pillar", "kit_ruin_se", "kit_ruin_sw"]], ["Grass", ["grass9_corner_top", "grass9_edge_ne", "grass9_corner_right", "grass9_edge_nw", "grass9_center", "grass9_edge_se", "grass9_corner_left", "grass9_edge_sw", "grass9_corner_bottom"]], ["Tall grass", ["grass_tall_00", "grass_tall_01", "grass_tall_02", "grass_tall_03"]]]
## Distance kept between a new object and the player / enemies so nothing is dropped on top of someone.
const ACTOR_CLEARANCE := 36.0

static var _tree_cache: Array = []


## Catalog entry for an id, including the arena's own placeholder walls ("base_N").
static func def_of(id: String) -> Dictionary:
	if CATALOG.has(id):
		return CATALOG[id]
	if id.begins_with("base_") and id.substr(5).is_valid_int():
		var n := id.substr(5).to_int()
		if n >= 0 and n < WorldScale.BLOCKS.size():
			var b: Array = WorldScale.BLOCKS[n]
			return {"label": "Wall" if float(b[2]) >= WorldScale.WALL_ART_MIN_HEIGHT else "Block", "kind": "block", "footprint": b[1], "height": float(b[2])}
	return {}

var arena: TrainingArena
var save_path := SAVE_PATH
var autosave := true
## Each entry: {"id": String, "pos": Vector2, "nodes": Array[Node]}
var objects: Array[Dictionary] = []
var _serial := 0
var hidden_types: Dictionary = {}


static func tree_info(index: int) -> Dictionary:
	if _tree_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlossomGrove.MANIFEST))
		_tree_cache = manifest.trees
	return _tree_cache[index]


const KIT_DIR := "res://assets/environment/kosen_courtyard/wall_kit_v2/"
const WALL_THICKNESS := 18.0


static func wall_texture(id: String) -> Texture2D:
	return load(KIT_DIR + String(def_of(id).art) + ".png") as Texture2D


## Ground rectangle covering a wall piece's collider (a strip along `col`, WALL_THICKNESS deep).
static func wall_rect(def: Dictionary, pos: Vector2) -> Rect2:
	var col: Vector2 = def.col
	var a := pos
	var b := pos + col
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y) - WALL_THICKNESS)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	if col == Vector2.ZERO:
		lo.x -= 16.0
		hi.x += 16.0
	return Rect2(lo, hi - lo)


## Nearest floor-diamond VERTEX (36a, 18b with a + b odd): where a wall piece's front-bottom-left corner sits.
static func iso_vertex(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	var k0 := int(floor(p.x / 36.0))
	var m0 := int(floor(p.y / 18.0))
	for k in [k0, k0 + 1]:
		for m in [m0, m0 + 1]:
			if posmod(k - m, 2) != 1:
				continue
			var c := Vector2(36.0 * k, 18.0 * m)
			var d := c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


static func footprint_of(id: String) -> Vector2:
	var def := def_of(id)
	if def.kind == "wall":
		return wall_rect(def, Vector2.ZERO).size
	return Vector2(72, 36) if def.kind == "grass" else WorldScale.TREE_TRUNK_FOOTPRINT if def.kind == "tree" else def.footprint


## The solid ground rectangle (BLOCKS convention: bottom-centre `pos`, extends `depth` upward).
static func footprint_rect(id: String, pos: Vector2) -> Rect2:
	var fp := footprint_of(id)
	if def_of(id).kind == "wall":
		return wall_rect(def_of(id), pos)
	if def_of(id).kind == "grass":
		return Rect2(pos - fp * 0.5, fp)  # a grass tile is centred on its diamond cell, not standing on it
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y, fp.x, fp.y)


## What a click on the object's picture should hit (the drawn volume, bigger than the solid base).
static func hit_rect(id: String, pos: Vector2) -> Rect2:
	var def := def_of(id)
	if def.kind == "grass":
		return Rect2(pos - Vector2(56, 136 if def.tall else 84), Vector2(112, 160 if def.tall else 112))
	if def.kind == "tree":
		return Rect2(pos.x - 110.0, pos.y - 330.0, 220.0, 350.0)
	if def.kind == "wall":
		return Rect2(pos - (def.anchor as Vector2), def.size)
	var fp: Vector2 = def.footprint
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y - float(def.height), fp.x + fp.y * 0.5, fp.y + float(def.height))


func can_place(id: String, pos: Vector2) -> bool:
	if arena == null or def_of(id).is_empty():
		return false
	var rect := footprint_rect(id, pos).grow(8.0)
	if not arena.bounds.encloses(rect):
		return false
	if def_of(id).kind == "grass":
		return true
	var actors: Array[Node] = []
	actors.append_array(get_tree().get_nodes_in_group("player"))
	actors.append_array(get_tree().get_nodes_in_group("enemy"))
	for a: Node in actors:
		if a is Node2D and rect.grow(ACTOR_CLEARANCE).has_point((a as Node2D).global_position):
			return false
	return true


func add(id: String, pos: Vector2, commit := true) -> Dictionary:
	if arena == null or def_of(id).is_empty():
		return {}
	var def := def_of(id)
	var nodes: Array[Node] = []
	_serial += 1
	if def.kind == "grass":
		var field := arena.get_node_or_null("WindGrassField") as WindGrassField
		if field == null:
			return {}
		var sprite := field.make_editable_sprite(id, pos)
		arena.add_child(sprite)
		nodes = [sprite]
	elif def.kind == "block":
		var fp: Vector2 = def.footprint
		var front := TrainingArena.Block.new(fp, float(def.height))
		front.name = "PlacedBlock%d" % _serial
		front.position = pos
		arena.add_child(front)
		var rear := TrainingArena.BlockRear.new(fp, float(def.height))
		rear.name = "PlacedBlockRear%d" % _serial
		rear.position = ArenaSort.rear_position(pos, fp)
		arena.add_child(rear)
		nodes = [front, rear]
	elif def.kind == "wall":
		nodes = _make_wall(id, pos)
	else:
		var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
		if grove == null:
			return {}
		var tree := grove.add_tree(int(def.tree), pos)
		nodes = [tree, _make_trunk(pos)]
	var obj := {"id": id, "pos": pos, "nodes": nodes}
	objects.append(obj)
	_apply_visibility(obj)
	if commit:
		_changed()
	return obj


## [sprite, collider]. The sprite sorts at the MIDDLE of its ground run (one key for a long diagonal piece); the collider is a thin parallelogram along it.
func _make_wall(id: String, pos: Vector2) -> Array[Node]:
	var def := def_of(id)
	var col: Vector2 = def.col
	var sprite := Sprite2D.new()
	sprite.name = "PlacedWall%d" % _serial
	sprite.texture = wall_texture(id)
	sprite.centered = false
	sprite.offset = -(def.anchor as Vector2) - col * 0.5
	sprite.position = pos + col * 0.5
	arena.add_child(sprite)
	var body := StaticBody2D.new()
	body.name = "PlacedWallBody%d" % _serial
	var shape := ConvexPolygonShape2D.new()
	if col == Vector2.ZERO:
		shape.points = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(14, -14), Vector2(-14, -14)])
	else:
		shape.points = PackedVector2Array([Vector2.ZERO, col, col + Vector2(0, -WALL_THICKNESS), Vector2(0, -WALL_THICKNESS)])
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	arena.add_child(body)
	return [sprite, body]


func _make_trunk(pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "PlacedTrunk%d" % _serial
	var shape := RectangleShape2D.new()
	shape.size = WorldScale.TREE_TRUNK_FOOTPRINT
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -WorldScale.TREE_TRUNK_FOOTPRINT.y * 0.5)
	body.add_child(col)
	body.position = pos
	arena.add_child(body)
	return body


## Take over the trees BlossomGrove spawned at start so they can be picked, moved and deleted like anything else.
func adopt_grove() -> int:
	if arena == null:
		return 0
	var n := 0
	for i in WorldScale.BLOCKS.size():
		var front := arena.get_node_or_null("Block%d" % i)
		var rear := arena.get_node_or_null("BlockRear%d" % i)
		if front != null and rear != null:
			_serial += 1
			objects.append({"id": "base_%d" % i, "pos": WorldScale.BLOCKS[i][0], "nodes": [front, rear]})
			n += 1
	var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
	if grove == null:
		_changed(false)
		return n
	for i in mini(grove.trees.size(), 5):
		var tree: BlossomTree = grove.trees[i]
		_serial += 1
		objects.append({"id": "tree_%d" % (i + 1), "pos": tree.position, "nodes": [tree, _make_trunk(tree.position)]})
		n += 1
	_changed(false)
	return n


## Original field becomes the same editable objects as newly placed grass.
func adopt_grass() -> int:
	var field := arena.get_node_or_null("WindGrassField") as WindGrassField
	if field == null:
		return 0
	field.ground.clear()
	field.tall.clear()
	for tile: Dictionary in field.initial_tiles:
		add(tile.id, tile.pos, false)
	return field.initial_tiles.size()


static func type_of(id: String) -> String:
	var def := def_of(id)
	return "Tall grass" if def.kind == "grass" and def.tall else "Grass" if def.kind == "grass" else "Trees" if def.kind == "tree" else "Temple walls" if def.kind == "wall" else "Walls & blocks"


func type_visible(id: String) -> bool:
	return not bool(hidden_types.get(type_of(id), false))


func _apply_visibility(obj: Dictionary) -> void:
	for n: Node in obj.nodes:
		if is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = type_visible(obj.id)


func set_type_visible(category: String, shown: bool) -> void:
	hidden_types[category] = not shown
	for obj in objects:
		if type_of(obj.id) == category:
			_apply_visibility(obj)


func remove(obj: Dictionary, commit := true) -> void:
	if not objects.has(obj):
		return
	objects.erase(obj)
	var def := def_of(obj.id)
	if def.kind == "grass":
		(arena.get_node("WindGrassField") as WindGrassField).removed_editable(obj.id)
	for n: Node in obj.nodes:
		if not is_instance_valid(n):
			continue
		if def.kind == "tree" and n is BlossomTree:
			var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
			if grove != null:
				grove.remove_tree(n as BlossomTree)
				continue
		n.queue_free()
	if commit:
		_changed()


func move(obj: Dictionary, pos: Vector2, commit := true) -> void:
	if not objects.has(obj):
		return
	obj.pos = pos
	var def := def_of(obj.id)
	var nodes: Array = obj.nodes
	if def.kind == "block":
		(nodes[0] as Node2D).position = pos
		(nodes[1] as Node2D).position = ArenaSort.rear_position(pos, def.footprint)
	elif def.kind == "wall":
		(nodes[0] as Node2D).position = pos + (def.col as Vector2) * 0.5
		(nodes[1] as Node2D).position = pos
	else:
		for n: Node2D in nodes:
			n.position = pos
	if commit:
		_changed()


## Topmost object under a world point: the solid base wins over the (larger) picture so crowded trees stay pickable.
func hit_test(point: Vector2) -> Dictionary:
	# Solid props win before grass; hiding a type lets the owner pick what is underneath it.
	for picture: bool in [false, true]:
		for i in range(objects.size() - 1, -1, -1):
			var o := objects[i]
			if not type_visible(o.id) or def_of(o.id).kind == "grass":
				continue
			var rect := hit_rect(o.id, o.pos) if picture else footprint_rect(o.id, o.pos).grow(10.0)
			if rect.has_point(point):
				return o
	var closest: Dictionary = {}
	var distance := INF
	for o in objects:
		if def_of(o.id).kind != "grass" or not type_visible(o.id):
			continue
		if hit_rect(o.id, o.pos).has_point(point):
			var d := point.distance_squared_to(o.pos)
			if d < distance:
				distance = d
				closest = o
	return closest


## BLOCKS-style entries [pos, footprint, height] for the bandit nav.
func obstacles() -> Array:
	var out: Array = []
	for o in objects:
		var kind: String = def_of(o.id).kind
		if kind == "wall":
			out.append_array(_wall_obstacles(def_of(o.id), o.pos))
		elif kind != "grass":
			out.append([o.pos, footprint_of(o.id), 0.0])
	return out


## One 36 x 36 nav box per floor cell the wall's collider crosses (the nav only knows axis-aligned boxes).
static func _wall_obstacles(def: Dictionary, pos: Vector2) -> Array:
	var col: Vector2 = def.col
	if col == Vector2.ZERO:
		return [[pos, Vector2(32, 16), 0.0]]
	var out: Array = []
	var steps := int(round(absf(col.x) / 36.0))
	var step := col / float(steps)
	for i in steps:
		var a := pos + step * float(i)
		out.append([Vector2(a.x + step.x * 0.5, maxf(a.y, a.y + step.y)), Vector2(36, 36), 0.0])
	return out


func clear_all(commit := true) -> void:
	for o in objects.duplicate():
		remove(o, false)
	if commit:
		_changed()


func to_dict() -> Dictionary:
	var items: Array = []
	for o in objects:
		items.append({"id": o.id, "x": snappedf(o.pos.x, 0.01), "y": snappedf(o.pos.y, 0.01)})
	return {"version": SAVE_VERSION, "items": items}


func to_json_string() -> String:
	return JSON.stringify(to_dict(), "\t")


func save() -> bool:
	# An empty world is never persisted: it would make the next boot start with no trees or walls.
	if objects.is_empty():
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
		return true
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_json_string())
	return true


## Rebuild a layout. Entries with an unknown id, bad numbers, outside the arena or on top of the spawn are skipped.
func load_dict(data: Dictionary) -> int:
	clear_all(false)
	if int(data.get("version", 1)) < 2:
		for i in WorldScale.TREE_POSITIONS.size():
			add("tree_%d" % (i + 1), WorldScale.TREE_POSITIONS[i], false)
	if int(data.get("version", 1)) < 3:
		for i in WorldScale.BLOCKS.size():
			add("base_%d" % i, WorldScale.BLOCKS[i][0], false)
	if int(data.get("version", 1)) < 4:
		adopt_grass()
	var made := 0
	var spawn := Vector2(0, 135)
	if arena != null and arena.has_node("Spawn"):
		spawn = (arena.get_node("Spawn") as Node2D).position
	for item in data.get("items", []):
		if typeof(item) != TYPE_DICTIONARY or def_of(str(item.get("id", ""))).is_empty():
			continue
		if typeof(item.get("x")) not in [TYPE_FLOAT, TYPE_INT] or typeof(item.get("y")) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var id := str(item.id)
		var pos := Vector2(float(item.x), float(item.y))
		var rect := footprint_rect(id, pos)
		if not pos.is_finite() or not arena.bounds.encloses(rect) or (def_of(id).kind != "grass" and rect.grow(60.0).has_point(spawn)):
			continue
		if not add(id, pos, false).is_empty():
			made += 1
	_changed(false)
	return made


func load_saved() -> int:
	if not FileAccess.file_exists(save_path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var items: Variant = parsed.get("items", [])
	if typeof(items) != TYPE_ARRAY or items.is_empty():
		return 0  # empty/garbled saves (older Clear-all autosaves) keep the default trees + walls
	var made := load_dict(parsed)
	if objects.is_empty():
		load_dict({"version": 1, "items": []})  # every entry was rejected: fall back to the defaults
	return made


func _changed(write := true) -> void:
	if arena != null:
		arena.rebuild_nav()
	if write and autosave:
		save()
