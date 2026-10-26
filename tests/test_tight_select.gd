extends RefCounted
## Picking is tight to the art: transparent corners of the old big click boxes no longer select anything, the
## visible pixels and the solid base still do, and the piece drawn in front wins an overlap.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 6:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_tight_select_layout.json"
	placed.autosave = false

	for o in placed.objects.duplicate():
		placed.remove(o)
	var pos := Vector2(1200, 700)
	var t := placed.add("tree_1", pos)
	ck.call("tight select: the test tree was placed", not t.is_empty())
	var old_box := PlacedObjects.hit_rect("tree_1", pos)
	var art := PlacedObjects.art_rect("tree_1", pos)
	ck.call("tight select: the art has a trimmed rect", art.size.x > 0.0 and art.size.y > 0.0, str(art.size))
	var corner := art.position + Vector2(3, 3)
	ck.call("tight select: the old box's transparent corner selects nothing", placed.hit_test(corner).is_empty(), str(placed.hit_test(corner).get("id","")) + str(placed.hit_test(corner).get("pos","")))
	ck.call("tight select: the solid base still selects the tree", placed.hit_test(pos + Vector2(0, -4)).get("pos", Vector2.INF) == pos, str(placed.hit_test(pos + Vector2(0, -4)).get("id","")) + str(placed.hit_test(pos + Vector2(0, -4)).get("pos","")))
	var solid := Vector2.INF
	for y in range(int(art.position.y), int(art.end.y), 4):
		for x in range(int(art.position.x), int(art.end.x), 4):
			if PlacedObjects.art_pixel_hit("tree_1", pos, Vector2(x, y), 0):
				solid = Vector2(x, y)
	ck.call("tight select: a visible pixel of the picture selects it", solid != Vector2.INF and placed.hit_test(solid).get("pos", Vector2.INF) == pos)
	var outside := art.position - Vector2(30, 30)
	ck.call("tight select: well outside the art selects nothing", placed.hit_test(outside).is_empty())

	var front := placed.add("tree_1", pos + Vector2(0, 40))
	ck.call("tight select: the piece in front (larger y) wins an overlap", placed.hit_test(pos + Vector2(0, 30)).get("pos", Vector2.INF) == pos + Vector2(0, 40))
	placed.remove(front)
	placed.remove(t)
	main.queue_free()
	await tree.process_frame
