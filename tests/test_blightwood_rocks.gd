extends RefCounted
## Three large Blightwood rocks: catalog entries, art, solid footprint, placeable and saved.

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
	placed.save_path = "user://test_blightwood_rocks_layout.json"
	placed.autosave = false
	var spot := (arena.get_node("Spawn") as Node2D).position + Vector2(0, 400)
	for n in 3:
		var id := "blight_rock_0%d" % (n + 1)
		ck.call("rock: %s is in the Blightwood rocks category" % id, PlacedObjects.type_of(id) == "Blightwood rocks")
		var tex := PlacedObjects.wall_texture(id)
		ck.call("rock: %s art loads and is large" % id, tex != null and tex.get_size().x >= 100.0)
		var o = placed.add(id, spot + Vector2(300 * n, 0), false)
		ck.call("rock: %s places" % id, o != null)
		var body: StaticBody2D = null
		if o != null:
			for nd in o.nodes:
				if nd is StaticBody2D:
					body = nd
		ck.call("rock: %s is solid" % id, body != null)
		ck.call("rock: %s is a nav obstacle" % id, placed.obstacles().size() >= n + 1)
	var json := placed.to_dict()
	var count := 0
	for it in json.items:
		if str(it.id).begins_with("blight_rock_"):
			count += 1
	ck.call("rock: all three are saved in the layout", count == 3, str(count))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	main.queue_free()
	await tree.process_frame
