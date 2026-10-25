extends RefCounted
## Builder pro tools: auto-tiling (edges + banks), rect / line fill, eyedropper, box select + group move/delete,
## copy / paste / saved stamps, layer lock + hide, and the problem scan.

var ck: Callable
const SE_STEP := Vector2(36, 18)
const NE_STEP := Vector2(36, -18)


func _block(a: Vector2, ni: int, nj: int) -> Array:
	var out: Array = []
	for i in ni:
		for j in nj:
			out.append(a + SE_STEP * float(i) + NE_STEP * float(j))
	return out


func _id_in(placed: PlacedObjects, cell: Vector2) -> String:
	var t := placed.floor_tiles_in_cell(cell)
	return String(t[0].id) if t.size() == 1 else "(%d tiles)" % t.size()


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = false
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_builder_pro_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	ed.stamp_path = "user://test_builder_pro_stamps.json"
	DirAccess.remove_absolute(ed.stamp_path)
	placed.load_dict({"version": 7, "items": []})
	placed.clear_history()
	var origin := PlacedObjects.lattice_center(arena.bounds.get_center())

	# --- terrain classification and 9-piece edges
	ck.call("autotile: terrain names", AutoTile.terrain_of("water9_edge_ne") == "water" and AutoTile.terrain_of("grass9_center") == "grass" and AutoTile.terrain_of("shore_grass_15") == "land" and AutoTile.terrain_of("shore_dirt_05") == "water" and AutoTile.terrain_of("tree_1") == "")
	var t := AutoTile.new(placed)
	t.apply(_block(origin, 3, 3), "grass")
	ck.call("autotile: a 3x3 grass patch gets a centre piece in the middle", _id_in(placed, origin + SE_STEP + NE_STEP) == "grass9_center")
	ck.call("autotile: its four tips are corner pieces", _id_in(placed, origin + NE_STEP * 2.0) == "grass9_corner_top" and _id_in(placed, origin + SE_STEP * 2.0 + NE_STEP * 2.0) == "grass9_corner_right" and _id_in(placed, origin + SE_STEP * 2.0) == "grass9_corner_bottom" and _id_in(placed, origin) == "grass9_corner_left")
	ck.call("autotile: its sides are edge pieces", _id_in(placed, origin + SE_STEP + NE_STEP * 2.0) == "grass9_edge_ne" and _id_in(placed, origin + NE_STEP) == "grass9_edge_nw" and _id_in(placed, origin + SE_STEP * 2.0 + NE_STEP) == "grass9_edge_se" and _id_in(placed, origin + SE_STEP) == "grass9_edge_sw")

	# --- water next to land becomes a bank piece
	var wcell := origin + SE_STEP * 3.0 + NE_STEP
	var t2 := AutoTile.new(placed)
	t2.apply([wcell], "water")
	ck.call("autotile: water with grass to its north-west gets the Bank NW grass piece", _id_in(placed, wcell) == "shore_grass_10")
	ck.call("autotile: the grass next to new water turns into a centre piece again", _id_in(placed, origin + SE_STEP * 2.0 + NE_STEP) == "grass9_center")
	var wpiece := AutoTile.new(placed)
	ck.call("autotile: land fills solid land corners (4 sides land is never a land-fill swap)", wpiece.corner_mask(wcell) == 10)

	# --- erasing re-fixes edges
	var before := placed.objects.size()
	ed.set_tool("erase")
	ed.press(wcell)
	ck.call("autotile: erasing a tile removes it", placed.objects.size() == before - 1 and placed.floor_tiles_in_cell(wcell).is_empty())
	ck.call("autotile: erase re-picks the neighbour's edge", _id_in(placed, origin + SE_STEP * 2.0 + NE_STEP) == "grass9_edge_se")

	# --- bank look override
	placed.load_dict({"version": 7, "items": []})
	var t3 := AutoTile.new(placed, "rock")
	t3.apply(_block(origin, 2, 2), "ground")
	t3.apply([origin + SE_STEP * 2.0], "water")
	ck.call("autotile: BANK LOOK rock forces the rock bank", _id_in(placed, origin + SE_STEP * 2.0).begins_with("shore_rock_"))
	var t4 := AutoTile.new(placed)
	t4.apply([origin + SE_STEP * 4.0 + NE_STEP], "water")
	ck.call("autotile: lone water far from land is plain water", _id_in(placed, origin + SE_STEP * 4.0 + NE_STEP).begins_with("water9_"))
	t4.apply([origin + SE_STEP * 2.0 + NE_STEP * 2.0], "temple")
	var temple_id := _id_in(placed, origin + SE_STEP * 2.0 + NE_STEP * 2.0)
	ck.call("autotile: temple paint uses the temple floor set", temple_id.begins_with("temple_floor_"))

	# --- editor: rect and line fill, one undo step
	placed.load_dict({"version": 7, "items": []})
	placed.clear_history()
	ed.set_terrain("grass")
	ck.call("tools: terrain tool selected", ed.tool == "terrain" and ed.auto_terrain == "grass")
	ed.set_shape("rect")
	ed.press(origin)
	ed.end_shape(origin + SE_STEP * 3.0 + NE_STEP * 2.0)
	var grass_count := 0
	for o in placed.objects:
		if String(o.id).begins_with("grass9_"):
			grass_count += 1
	ck.call("tools: a rect drag fills the whole box (4 x 3 = 12 cells)", grass_count == 12)
	ck.call("tools: the fill is auto-tiled (corner on the tip)", _id_in(placed, origin) == "grass9_corner_left")
	placed.undo()
	ck.call("tools: one undo removes the entire rect fill", placed.objects.is_empty())
	ed.set_shape("line")
	ed.press(origin)
	ed.end_shape(origin + SE_STEP * 4.0)
	ck.call("tools: a line drag lays a straight run (5 cells)", placed.objects.size() == 5)
	placed.undo()
	ed.set_shape("brush")
	ed.set_terrain("water")
	ed.press(origin)
	ed.end_stroke()
	ck.call("tools: the brush paints one auto-tiled water cell", placed.objects.size() == 1 and String(placed.objects[0].id).begins_with("water9_"))
	ed.set_terrain("")
	ed.press(origin)
	ed.end_stroke()
	ck.call("tools: CLEAR terrain wipes the floor under the brush", placed.objects.is_empty())

	# --- eyedropper
	placed.load_dict({"version": 7, "items": []})
	AutoTile.new(placed).apply([origin], "grass")
	ed.set_tool("select")
	ck.call("eyedrop: picking a floor tile switches to paint with that tile", ed.eyedrop(origin) and ed.tool == "paint" and ed.place_id == _id_in(placed, origin))
	ed.set_terrain("water")
	ed.eyedrop(origin)
	ck.call("eyedrop: with the terrain tool it picks the terrain", ed.tool == "terrain" and ed.auto_terrain == "grass")
	ck.call("eyedrop: empty ground picks nothing", not ed.eyedrop(origin + Vector2(2000, 1000)))
	var prop := placed.add("tree_1", origin + Vector2(400, 300))
	ed.eyedrop((prop.pos as Vector2) + Vector2(0, -40))
	ck.call("eyedrop: picking a prop switches to the place tool", ed.tool == "place" and ed.place_id == "tree_1")

	# --- box select, group move, delete
	placed.load_dict({"version": 7, "items": []})
	placed.clear_history()
	var a := placed.add("tree_1", origin)
	var b := placed.add("tree_2", origin + Vector2(120, 0))
	placed.add("tree_3", origin + Vector2(1200, 0))
	ed.set_tool("box")
	ed.press(origin + Vector2(-200, -500))
	var n := ed.end_box(origin + Vector2(300, 100))
	ck.call("box: selects exactly the objects in the box", n == 2 and ed.selection.size() == 2 and not ed.selection.has(placed.objects[2]))
	ed.set_tool("select")
	ck.call("box: switching to select keeps the group", ed.selection.size() == 2)
	var pa: Vector2 = a.pos
	var pb: Vector2 = b.pos
	ed.press((a.pos as Vector2) + Vector2(0, -40))
	ck.call("box: pressing a member starts a group drag", ed._group_dragging)
	ed.drag_to((a.pos as Vector2) + Vector2(0, -40) + Vector2(60, 0))
	ed.release()
	ck.call("box: the group moves together", (a.pos as Vector2).distance_to(pa + Vector2(60, 0)) < 31.0 and (b.pos as Vector2).distance_to(pb + Vector2(60, 0)) < 31.0 and ((b.pos as Vector2) - (a.pos as Vector2)).is_equal_approx(pb - pa))
	placed.undo()
	ck.call("box: one undo puts the whole group back", (a.pos as Vector2).is_equal_approx(pa) and (b.pos as Vector2).is_equal_approx(pb))
	ed.select_in_rect(Rect2(origin + Vector2(-200, -500), Vector2(500, 600)))
	var count_before := placed.objects.size()
	ed.delete_selected()
	ck.call("box: delete removes the whole group", placed.objects.size() == count_before - 2)
	placed.undo()
	ck.call("box: one undo brings the group back", placed.objects.size() == count_before)

	# --- copy / paste / stamps
	placed.load_dict({"version": 7, "items": []})
	placed.clear_history()
	AutoTile.new(placed).apply(_block(origin, 2, 2), "temple")
	placed.add("tree_1", origin + SE_STEP * 0.5 + Vector2(0, 40))
	ed.set_tool("box")
	ed.press(origin + Vector2(-100, -300))
	ed.end_box(origin + Vector2(300, 300))
	ck.call("copy: box selects the floor and the prop", ed.selection.size() == 5)
	var copied := ed.copy_selection()
	ck.call("copy: Ctrl+C captures everything", copied == 5 and ed.clipboard.size() == 5)
	var far := origin + Vector2(1080, 360)
	var n0 := placed.objects.size()
	ed.begin_paste()
	ck.call("paste: the stamp tool is armed", ed.tool == "stamp")
	var pasted := ed.paste_at(far)
	ck.call("paste: drops all pieces", pasted == 5 and placed.objects.size() == n0 + 5)
	placed.undo()
	ck.call("paste: one undo removes the whole drop", placed.objects.size() == n0)
	ed.set_tool("box")
	ed.press(origin + Vector2(-100, -300))
	ed.end_box(origin + Vector2(300, 300))
	ck.call("stamps: SAVE STAMP stores the selection", ed.save_stamp("Courtyard") and StampStore.load_all(ed.stamp_path).size() == 1)
	ck.call("stamps: the panel lists it", ed.stamps_box.get_child_count() == 1)
	ed.clipboard = []
	ed.use_stamp(0)
	ck.call("stamps: using it loads the clipboard and arms the stamp tool", ed.clipboard.size() == 5 and ed.tool == "stamp")
	ed.delete_stamp(0)
	ck.call("stamps: delete removes it", StampStore.load_all(ed.stamp_path).is_empty() and ed.stamps_box.get_child_count() == 0)

	# --- layers
	placed.load_dict({"version": 7, "items": []})
	AutoTile.new(placed).apply([origin], "temple")
	var layer := PlacedObjects.type_of(_id_in(placed, origin))
	ck.call("layers: the layer rows exist", ed._layer_buttons.has(layer))
	ck.call("layers: unlocked floor can be picked", not placed.hit_test(origin).is_empty())
	ed.set_layer_locked(layer, true)
	ck.call("layers: a locked layer cannot be picked", placed.hit_test(origin).is_empty())
	ck.call("layers: nor painted over", not placed.paint_cell("ground9_center", origin))
	ck.call("layers: nor box-selected", placed.objects_in_rect(Rect2(origin - Vector2(100, 100), Vector2(200, 200))).is_empty())
	ed.set_layer_locked(layer, false)
	ed.set_layer_hidden(layer, true)
	ck.call("layers: hide turns the layer invisible", not placed.type_visible(_id_in(placed, origin)))
	ed.set_layer_hidden(layer, false)
	ck.call("layers: show brings it back", placed.type_visible(_id_in(placed, origin)))

	# --- problem scan
	placed.load_dict({"version": 7, "items": []})
	ck.call("problems: an empty map is clean", ProblemScan.scan(placed).is_empty())
	placed.add("tree_1", origin)
	placed.add("tree_1", origin)
	var kinds := {}
	for pr in ProblemScan.scan(placed):
		kinds[pr.kind] = true
	ck.call("problems: two props on the same spot are stacked", kinds.has("stacked"))
	placed.load_dict({"version": 7, "items": []})
	placed.add("tree_1", origin)
	placed.add("tree_2", origin + Vector2(10, 0))
	kinds = {}
	for pr in ProblemScan.scan(placed):
		kinds[pr.kind] = true
	ck.call("problems: overlapping props are flagged", kinds.has("overlap"))
	placed.load_dict({"version": 7, "items": []})
	placed.add("shore_grass_05", origin)
	kinds = {}
	for pr in ProblemScan.scan(placed):
		kinds[pr.kind] = true
	ck.call("problems: a floating bank piece is flagged", kinds.has("shore"))
	placed.load_dict({"version": 7, "items": []})
	placed.add("grass9_center", origin)
	placed.add("water9_center", origin + SE_STEP)
	kinds = {}
	for pr in ProblemScan.scan(placed):
		kinds[pr.kind] = true
	ck.call("problems: water touching land with no bank is flagged", kinds.has("bank"))
	var fixed := AutoTile.new(placed)
	fixed.retile(origin + SE_STEP)
	ck.call("problems: auto-tile retile fixes the missing bank", ProblemScan.scan(placed).filter(func(x): return x.kind == "bank" or x.kind == "shore").is_empty())
	ck.call("problems: SCAN + NEXT PROBLEM run", ed.scan_problems() >= 0)

	# --- UI
	ck.call("ui: terrain, shape and tool buttons exist", ed._terrain_buttons.has("water") and ed._terrain_buttons.has("") and ed._shape_buttons.has("rect") and ed._tool_buttons.has("box"))
	ck.call("ui: the pro-tools block is open in the map editor", ed.tools_body.visible)
	ed.set_pro_tools_open(false)
	ck.call("ui: the block collapses", not ed.tools_body.visible)
	ed.set_pro_tools_open(true)

	main.queue_free()
	MapEditorMode.forced = false
	DirAccess.remove_absolute(ed.stamp_path)
	await tree.process_frame
