extends RefCounted
## Ancient Shrine landmark (Codex art, Blightwood palette): catalog entry, collision, starting-level placement, v6 -> v7 migration.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 5:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_ancient_shrine_layout.json"
	placed.autosave = false

	var def := PlacedObjects.def_of("ancient_shrine")
	ck.call("shrine: catalog entry exists under Landmarks", not def.is_empty() and PlacedObjects.type_of("ancient_shrine") == "Landmarks")
	var tex := PlacedObjects.wall_texture("ancient_shrine")
	ck.call("shrine: Codex art loads (256x256)", tex != null and tex.get_size() == Vector2(256, 256))
	ck.call("shrine: it is already in the starting level, exactly once", _count(placed) == 1, str(_count(placed)))
	var obj := {}
	for o in placed.objects:
		if o.id == "ancient_shrine":
			obj = o
	var pos: Vector2 = obj.pos
	var spawn := (arena.get_node("Spawn") as Node2D).position
	ck.call("shrine: it stands clear of the spawn and inside the arena", pos.distance_to(spawn) > 300.0 and arena.bounds.encloses(PlacedObjects.footprint_rect("ancient_shrine", pos)))
	var body: StaticBody2D = null
	for n in obj.nodes:
		if n is StaticBody2D:
			body = n
	ck.call("shrine: it is solid (has a collision body)", body != null)
	ck.call("shrine: its footprint is a nav obstacle", placed.obstacles().size() >= 1 and _has_obstacle(placed, pos))
	placed.move(obj, pos + Vector2(40, 0), false)
	ck.call("shrine: it can be moved", (obj.nodes[0] as Node2D).global_position.x > pos.x + 1.0 or (body != null and body.position.x > pos.x + 1.0))

	var json := placed.to_dict()
	ck.call("shrine: it is saved in the layout", _in_items(json, "ancient_shrine") == 1 and int(json.version) == PlacedObjects.SAVE_VERSION)
	placed.load_dict(json)
	ck.call("shrine: reloading the layout keeps exactly one", _count(placed) == 1)
	# an older (v6) layout without a shrine gets one added on boot
	var old := {"version": 6, "items": [{"id": "tree_1", "x": -920, "y": 320}]}
	placed.load_dict(old)
	ck.call("shrine: a v6 layout starts without one", _count(placed) == 0)
	ck.call("shrine: ensure_shrine adds it once", placed.ensure_shrine() and _count(placed) == 1 and not placed.ensure_shrine() and _count(placed) == 1)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	main.queue_free()
	await tree.process_frame


func _count(placed: PlacedObjects) -> int:
	var n := 0
	for o in placed.objects:
		if o.id == "ancient_shrine":
			n += 1
	return n


func _in_items(json: Dictionary, id: String) -> int:
	var n := 0
	for it in json.items:
		if it.id == id:
			n += 1
	return n


func _has_obstacle(placed: PlacedObjects, pos: Vector2) -> bool:
	for ob in placed.obstacles():
		if (ob[0] as Vector2).distance_to(pos) < 1.0:
			return true
	return false
