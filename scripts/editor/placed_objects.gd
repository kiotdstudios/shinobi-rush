class_name PlacedObjects
extends Node
## The player-editable layer of the arena: trees, walls and other built objects placed with the World Builder
## (WorldEditor). Every object is solid (player + bandit nav) and is saved to disk so a layout survives restarts.
## To add a new buildable thing, add ONE row to CATALOG (and an id to CATEGORIES so it shows in the panel).
##   kind "block": a placeholder box (TrainingArena.Block/BlockRear) with `footprint` (w, depth) and `height`.
##   kind "tree":  one of the five Codex blossom trees (index into blossom_trees.art.json); solid trunk base only.
const SAVE_PATH := "user://world_builder_layout.json"
## v2 saves list EVERY object (the starting trees included); a v1 save only listed additions, so it also gets the default trees.
const SAVE_VERSION := 2
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
}
## Panel sections: [title, [ids]].
const CATEGORIES := [["Trees", ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]], ["Walls & blocks", ["wall_h", "wall_v", "rock", "crate"]]]
## Distance kept between a new object and the player / enemies so nothing is dropped on top of someone.
const ACTOR_CLEARANCE := 36.0

static var _tree_cache: Array = []

var arena: TrainingArena
var save_path := SAVE_PATH
var autosave := true
## Each entry: {"id": String, "pos": Vector2, "nodes": Array[Node]}
var objects: Array[Dictionary] = []
var _serial := 0


static func tree_info(index: int) -> Dictionary:
	if _tree_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlossomGrove.MANIFEST))
		_tree_cache = manifest.trees
	return _tree_cache[index]


static func footprint_of(id: String) -> Vector2:
	var def: Dictionary = CATALOG[id]
	return WorldScale.TREE_TRUNK_FOOTPRINT if def.kind == "tree" else def.footprint


## The solid ground rectangle (BLOCKS convention: bottom-centre `pos`, extends `depth` upward).
static func footprint_rect(id: String, pos: Vector2) -> Rect2:
	var fp := footprint_of(id)
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y, fp.x, fp.y)


## What a click on the object's picture should hit (the drawn volume, bigger than the solid base).
static func hit_rect(id: String, pos: Vector2) -> Rect2:
	var def: Dictionary = CATALOG[id]
	if def.kind == "tree":
		return Rect2(pos.x - 110.0, pos.y - 330.0, 220.0, 350.0)
	var fp: Vector2 = def.footprint
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y - float(def.height), fp.x + fp.y * 0.5, fp.y + float(def.height))


func can_place(id: String, pos: Vector2) -> bool:
	if arena == null or not CATALOG.has(id):
		return false
	var rect := footprint_rect(id, pos).grow(8.0)
	if not arena.bounds.encloses(rect):
		return false
	var actors: Array[Node] = []
	actors.append_array(get_tree().get_nodes_in_group("player"))
	actors.append_array(get_tree().get_nodes_in_group("enemy"))
	for a: Node in actors:
		if a is Node2D and rect.grow(ACTOR_CLEARANCE).has_point((a as Node2D).global_position):
			return false
	return true


func add(id: String, pos: Vector2, commit := true) -> Dictionary:
	if arena == null or not CATALOG.has(id):
		return {}
	var def: Dictionary = CATALOG[id]
	var nodes: Array[Node] = []
	_serial += 1
	if def.kind == "block":
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
	else:
		var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
		if grove == null:
			return {}
		var tree := grove.add_tree(int(def.tree), pos)
		nodes = [tree, _make_trunk(pos)]
	var obj := {"id": id, "pos": pos, "nodes": nodes}
	objects.append(obj)
	if commit:
		_changed()
	return obj


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
	var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove if arena != null else null
	if grove == null:
		return 0
	var n := 0
	for i in mini(grove.trees.size(), 5):
		var tree: BlossomTree = grove.trees[i]
		_serial += 1
		objects.append({"id": "tree_%d" % (i + 1), "pos": tree.position, "nodes": [tree, _make_trunk(tree.position)]})
		n += 1
	_changed(false)
	return n


func remove(obj: Dictionary, commit := true) -> void:
	if not objects.has(obj):
		return
	objects.erase(obj)
	var def: Dictionary = CATALOG[obj.id]
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
	var def: Dictionary = CATALOG[obj.id]
	var nodes: Array = obj.nodes
	if def.kind == "block":
		(nodes[0] as Node2D).position = pos
		(nodes[1] as Node2D).position = ArenaSort.rear_position(pos, def.footprint)
	else:
		(nodes[0] as Node2D).position = pos
		(nodes[1] as Node2D).position = pos
	if commit:
		_changed()


## Topmost object under a world point: the solid base wins over the (larger) picture so crowded trees stay pickable.
func hit_test(point: Vector2) -> Dictionary:
	for i in range(objects.size() - 1, -1, -1):
		var o := objects[i]
		if footprint_rect(o.id, o.pos).grow(10.0).has_point(point):
			return o
	for i in range(objects.size() - 1, -1, -1):
		var o := objects[i]
		if hit_rect(o.id, o.pos).has_point(point):
			return o
	return {}


## BLOCKS-style entries [pos, footprint, height] for the bandit nav.
func obstacles() -> Array:
	var out: Array = []
	for o in objects:
		out.append([o.pos, footprint_of(o.id), 0.0])
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
	var made := 0
	var spawn := Vector2(0, 135)
	if arena != null and arena.has_node("Spawn"):
		spawn = (arena.get_node("Spawn") as Node2D).position
	for item in data.get("items", []):
		if typeof(item) != TYPE_DICTIONARY or not CATALOG.has(str(item.get("id", ""))):
			continue
		if typeof(item.get("x")) not in [TYPE_FLOAT, TYPE_INT] or typeof(item.get("y")) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var id := str(item.id)
		var pos := Vector2(float(item.x), float(item.y))
		var rect := footprint_rect(id, pos)
		if not arena.bounds.encloses(rect) or rect.grow(60.0).has_point(spawn):
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
	return load_dict(parsed)


func _changed(write := true) -> void:
	if arena != null:
		arena.rebuild_nav()
	if write and autosave:
		save()
