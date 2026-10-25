extends SceneTree
## Dev tool: auto-tiled lake + island + temple patch in the map editor. godot --path . --script res://tools/shot_autotile.gd -- out.png

func _init() -> void:
	var out := "user://autotile.png"
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
	var o := PlacedObjects.lattice_center(arena.bounds.get_center())
	var se := Vector2(36, 18)
	var ne := Vector2(36, -18)
	var t := AutoTile.new(placed)
	var land: Array = []
	for i in 12:
		for j in 9:
			land.append(o + se * float(i) + ne * float(j))
	t.apply(land, "grass")
	var lake: Array = []
	for i in range(3, 9):
		for j in range(2, 7):
			if not (i in [3, 8] and j in [2, 6]):
				lake.append(o + se * float(i) + ne * float(j))
	t.apply(lake, "water")
	var isle: Array = []
	for i in range(5, 7):
		for j in range(3, 5):
			isle.append(o + se * float(i) + ne * float(j))
	t.apply(isle, "temple")
	arena.editor.void_check = false
	arena.editor.set_open(true)
	var cam := arena.editor._camera()
	if cam != null:
		cam.offset += (o + se * 6.0 + ne * 4.0) - cam.get_screen_center_position()
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
