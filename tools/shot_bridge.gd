extends SceneTree
## Dev tool: a lake crossed by an intact bridge, a broken bridge and a rope bridge. godot --path . --script res://tools/shot_bridge.gd -- out.png

func _init() -> void:
	var out := "user://bridge.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.size = Vector2i(1280, 720)
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	placed.load_dict({"version": 7, "items": []})
	var o := PlacedObjects.iso_vertex(arena.bounds.get_center())
	var se := Vector2(36, 18)
	var ne := Vector2(36, -18)
	var t := AutoTile.new(placed)
	var land: Array = []
	for i in 22:
		for j in 14:
			land.append(PlacedObjects.lattice_center(o) + se * float(i - 4) + ne * float(j))
	t.apply(land, "grass")
	var lake: Array = []
	for i in range(4, 12):
		for j in range(0, 14):
			lake.append(PlacedObjects.lattice_center(o) + se * float(i - 4) + ne * float(j))
	t.apply(lake, "water")
	placed.add("bridge_medium_wood_u", o + ne * 2.0 - se * 1.0, false)
	placed.add("bridge_medium_damaged_u", o + ne * 6.0 - se * 1.0, false)
	placed.add("bridge_medium_rope_u", o + ne * 10.0 - se * 1.0, false)
	arena.editor.void_check = false
	arena.editor.set_open(true)
	var cam := arena.editor._camera()
	if cam != null:
		cam.offset += (o + se * 2.0 + ne * 6.0) - cam.get_screen_center_position()
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
