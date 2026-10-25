extends RefCounted
## Floor tiles replace each other, temple ground can be deleted and stays deleted, flat grass is floor
## (drawn under fences), and the editor shows a white void instead of the default stone.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 6:
		await tree.process_frame
	AncientShrineSection.enabled = false
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_floor_replace_layout.json"
	placed.autosave = false

	ck.call("floor: the starting area is flagged as applied", placed.shrine_section_applied)
	var lay := AncientShrineSection.layout()
	var cell: Vector2 = lay.floor[27][1]
	var before := placed.floor_tiles_in_cell(cell)
	ck.call("floor: exactly one tile per starting-area cell", before.size() == 1, str(before.size()))

	var changed := placed.paint_cell("ground9_center", cell)
	var after := placed.floor_tiles_in_cell(cell)
	ck.call("floor: painting over an off-lattice temple tile replaces it", changed and after.size() == 1 and after[0].id == "ground9_center", str(after.size()))

	changed = placed.paint_cell("grass9_center", cell)
	after = placed.floor_tiles_in_cell(cell)
	ck.call("floor: flat grass replaces ground and vice versa", changed and after.size() == 1 and after[0].id == "grass9_center", str(after.size()))
	var grass: Node = after[0].nodes[0]
	ck.call("floor: flat grass sits on the Ground layer (under fences and actors)", grass.get_parent() == arena.get_node("Ground"))
	var clear_cell := Vector2(36, 18)
	placed.paint_cell("ground9_center", clear_cell)
	var cur := placed.hit_test(clear_cell)
	ck.call("floor: a floor tile can be picked to delete", not cur.is_empty() and PlacedObjects.is_floor_tile(cur.id), str(cur.get("id", "")))
	placed.remove(placed.floor_tiles_in_cell(clear_cell)[0], false)
	ck.call("floor: deleting leaves the cell empty", placed.floor_tiles_in_cell(clear_cell).is_empty())
	placed.remove(after[0], false)

	var tile: Dictionary = placed.floor_tiles_in_cell(lay.floor[3][1])[0]
	placed.remove(tile, false)
	var data := placed.to_dict()
	ck.call("floor: the save records that the section was applied", bool(data.get("shrine_section", false)))
	placed.load_dict(data)
	AncientShrineSection.enabled = true
	AncientShrineSection.populate(arena)
	AncientShrineSection.enabled = false
	ck.call("floor: a deleted temple tile does not come back after a reload", placed.floor_tiles_in_cell(lay.floor[3][1]).is_empty())
	ck.call("floor: reloading does not stack duplicates", placed.floor_tiles_in_cell(lay.floor[5][1]).size() == 1)

	var dup := placed.add("ground9_center", Vector2(36, 18), false)
	var dup2 := placed.add("ground9_center", Vector2(36, 18), false)
	var n := placed.dedupe_floor()
	ck.call("floor: exact duplicate tiles are collapsed", not dup.is_empty() and not dup2.is_empty() and n >= 1 and placed.floor_tiles_in_cell(Vector2(36, 18)).size() == 1)

	var ed := arena.editor
	ed.set_open(true)
	await tree.process_frame
	var tiles := arena.get_node("Ground/FloorTiles") as TileMapLayer
	ck.call("void: opening the editor hides the stone floor and shows white", not tiles.visible and ed.void_sheet.visible)
	ed.set_open(false)
	ck.call("void: the stone floor stays hidden in play too", not tiles.visible and ed.void_sheet.visible)

	# save checker: blocked while white void remains, jumps the view to it, passes once filled
	ed.void_check = true
	var voids := placed.void_cells(arena.bounds)
	ck.call("void checker: an unfinished level has void cells", voids.size() > 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	var saved := ed.save_now()
	ck.call("void checker: save is refused with a SAVE BLOCKED message", not saved and "SAVE BLOCKED" in ed.status.text and not FileAccess.file_exists(placed.save_path))
	ck.call("void checker: focus lands on a void cell", ed.void_focus != Vector2.INF and voids.has(ed.void_focus))
	ck.call("void checker: publish is refused too", not ed.publish_to_github())
	var cam := ed._camera()
	if cam != null:
		ck.call("void checker: camera centres on the void cell", cam.get_screen_center_position().distance_to(ed.void_focus) < 2.0, str(cam.get_screen_center_position()) + " vs " + str(ed.void_focus))
	for c in voids:
		placed.add("ground9_center", c, false)
	ck.call("void checker: no void cells once every cell has art", placed.void_cells(arena.bounds).is_empty())
	ck.call("void checker: a filled level saves", ed.save_now() and FileAccess.file_exists(placed.save_path))
	ed.void_check = false

	main.queue_free()
	await tree.process_frame
