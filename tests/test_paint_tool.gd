extends RefCounted
## Builder PAINT tool + the stone "Temple ground" tiles (Ashen Ruins floor).

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
	placed.save_path = "user://test_paint_layout.json"
	placed.autosave = false
	var editor := arena.editor
	editor.set_open(true)

	var ids: Array = []
	for cat in PlacedObjects.CATEGORIES:
		if cat[0] == "Temple ground":
			ids = cat[1]
	ck.call("temple ground: the palette section holds all 13 stone floor tiles", ids.size() == 13)
	var tex_ok := true
	for id in ids:
		var t := PlacedObjects.ground_texture(id)
		tex_ok = tex_ok and t != null and t.get_size() == Vector2(72, 36) and PlacedObjects.type_of(id) == "Temple ground"
	ck.call("temple ground: every tile loads as a 72x36 diamond and is typed Temple ground", tex_ok)
	ck.call("temple ground: the builder has a filter checkbox and a palette section for it", editor._filter_buttons.has("Temple ground") and editor._category_sections.has("Temple ground"))
	editor.set_type_filter("Temple ground", false)
	ck.call("temple ground: unchecking hides just that section", not (editor._category_sections["Temple ground"] as Control).visible)
	editor.set_type_filter("Temple ground", true)
	ck.call("paint: the editor has a PAINT button", editor._tool_buttons.has("paint"))

	# paint a stroke
	editor.set_tool("paint", "temple_floor_cracked_a")
	ck.call("paint: choosing the tool keeps the chosen tile", editor.tool == "paint" and editor.place_id == "temple_floor_cracked_a")
	var before := placed.objects.size()
	var start := Vector2(0, -900)
	editor.press(start)
	for k in range(1, 8):
		editor.paint_to(start + Vector2(36.0 * k, 18.0 * k))
	editor.end_stroke()
	var laid := placed.objects.size() - before
	ck.call("paint: dragging lays a run of tiles (8 cells)", laid == 8, str(laid))
	var cells := {}
	for o in placed.objects:
		if o.id == "temple_floor_cracked_a":
			cells[o.pos] = true
	ck.call("paint: every tile sits on its own floor-grid cell", cells.size() == 8)
	var n := placed.objects.size()
	editor.press(start)
	editor.end_stroke()
	ck.call("paint: painting the same tile again changes nothing", placed.objects.size() == n)
	editor.set_tool("paint", "temple_floor_moss_a")
	editor.press(start)
	editor.end_stroke()
	var here := placed.ground_at(iso(start, editor))
	ck.call("paint: a different tile replaces the old one in that cell", placed.objects.size() == n and here.id == "temple_floor_moss_a")
	editor.brush = 3
	var b0 := placed.objects.size()
	editor.press(Vector2(600, -900))
	editor.end_stroke()
	ck.call("paint: a 3 x 3 brush lays 9 tiles with one click", placed.objects.size() - b0 == 9, str(placed.objects.size() - b0))
	editor.brush = 1

	# saved + reloaded
	var json := placed.to_dict()
	placed.load_dict(json)
	var back := 0
	for o in placed.objects:
		if String(o.id).begins_with("temple_floor_"):
			back += 1
	ck.call("paint: painted tiles survive save and reload", back == 8 + 9, str(back))
	# erase still removes one
	editor.set_tool("erase")
	var victim := placed.ground_at(iso(start, editor))
	placed.remove(victim, false)
	ck.call("paint: a painted tile can be erased", placed.ground_at(iso(start, editor)).is_empty())
	# right-click path: switching tool ends painting
	editor.set_tool("select")
	ck.call("paint: leaving the tool is clean", editor.tool == "select")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	main.queue_free()
	await tree.process_frame


func iso(p: Vector2, editor: WorldEditor) -> Vector2:
	return WorldEditor.iso_cell_center(p)
