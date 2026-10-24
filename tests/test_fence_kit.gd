extends RefCounted
## Fence kit (PixelLab, Blightwood palette): catalog, category, solidity, save/load round trip.

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
	placed.save_path = "user://test_fence_kit_layout.json"
	placed.autosave = false

	var ids: Array = []
	for cat: Array in PlacedObjects.CATEGORIES:
		if cat[0] == "Fences":
			ids = cat[1]
	ck.call("fence: 'Fences' category lists 8 pieces", ids.size() == 8, str(ids.size()))
	var all_ok := true
	for id: String in ids:
		var tex := PlacedObjects.wall_texture(id)
		if tex == null or PlacedObjects.type_of(id) != "Fences":
			all_ok = false
	ck.call("fence: every piece has art and reports type Fences", all_ok)
	ck.call("fence: SE x2 art is 188x152", PlacedObjects.wall_texture("fence_se_2").get_size() == Vector2(188, 152))

	var base := (arena.get_node("Spawn") as Node2D).position + Vector2(300, 0)
	var objs: Array = []
	for id: String in ids:
		var o := placed.add(id, base, false)
		objs.append(o)
		base += Vector2(0, 60)
	var solid := true
	for o: Dictionary in objs:
		var has_body := false
		for n in o.nodes:
			if n is StaticBody2D:
				has_body = true
		if not has_body:
			solid = false
	ck.call("fence: all pieces are solid", solid)

	var json := placed.to_dict()
	for o: Dictionary in objs.duplicate():
		placed.remove(o, false)
	await tree.process_frame
	placed.load_dict(json)
	await tree.process_frame
	var n_fence := 0
	for o in placed.objects:
		if String(o.id).begins_with("fence_"):
			n_fence += 1
	ck.call("fence: pieces survive save/load", n_fence == 8, str(n_fence))
	main.queue_free()
	await tree.process_frame
