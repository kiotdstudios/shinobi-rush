extends RefCounted

func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	var editor := arena.editor
	editor.set_open(true)
	ck.call("ground builder: dedicated palette filter exists", editor._filter_buttons.has("Ground / paths"))
	var before := placed.obstacles().size()
	var count := 0
	for id: String in PlacedObjects.CATALOG:
		if PlacedObjects.def_of(id).kind != "ground" or not String(id).begins_with("ground9_"):
			continue
		count += 1
		var pos := Vector2(-216 + count * 72, 900)
		var obj := placed.add(id, pos, false)
		ck.call("ground builder: place " + id, not obj.is_empty() and placed.can_place(id, pos))
		var sprite := obj.nodes[0] as Sprite2D
		ck.call("ground builder: below grass, native scale " + id, sprite.get_parent().name == "Ground" and sprite.texture.get_size() == Vector2(72, 36) and sprite.scale == Vector2.ONE)
	ck.call("ground builder: all nine registered without nav obstacles", count == 9 and placed.obstacles().size() == before)
	editor.set_tool("place", "ground9_center")
	ck.call("ground builder: snaps to floor center", editor.snapped_pos(Vector2(75, 5)) == Vector2(72, 0))
	editor.set_type_filter("Ground / paths", false)
	ck.call("ground builder: hiding palette cancels paint", editor.tool == "select" and not editor._category_sections["Ground / paths"].visible)
	var data := placed.to_dict()
	placed.load_dict(data)
	var found := 0
	for obj in placed.objects.duplicate():
		if PlacedObjects.def_of(obj.id).kind == "ground" and String(obj.id).begins_with("ground9_"):
			found += 1
			placed.remove(obj, false)
	ck.call("ground builder: save/load retains nine ground tiles", found == 9)
	var tile := placed.add("ground9_center", Vector2(720, 900), false)
	placed.move(tile, Vector2(792, 900), false)
	ck.call("ground builder: move updates picture and diamond hit", (tile.nodes[0] as Node2D).position == Vector2(792, 900) and placed.hit_test(Vector2(792, 900)).get("id", "") == "ground9_center")
	placed.remove(tile, false)
	ck.call("ground builder: delete removes object", not placed.objects.has(tile))
	main.queue_free()
	await root.get_tree().process_frame
