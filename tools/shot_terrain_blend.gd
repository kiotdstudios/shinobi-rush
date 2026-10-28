extends SceneTree
## Dev tool: Auto Blend proof sheet (grass field with a dirt trail: straight, bend, T, 4-way, island, plus ground/temple/rock patches
## and a pond). godot --path . --script res://tools/shot_terrain_blend.gd -- out.png   (needs a window, not --headless)

func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	await process_frame
	var out := "user://terrain_blend.png"
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
	t.blend = true
	var field: Array = []
	for i in 16:
		for j in 12:
			field.append(o + se * float(i) + ne * float(j))
	t.apply(field, "grass")
	var trail: Array = []
	for i in range(0, 9):
		trail.append(o + se * float(i) + ne * 3.0)  # straight run
	for j in range(3, 9):
		trail.append(o + se * 8.0 + ne * float(j))  # bend
	for j in range(0, 3):
		trail.append(o + se * 4.0 + ne * float(j))  # T branch
	for i in range(9, 13):
		trail.append(o + se * float(i) + ne * 6.0)  # 4-way crossing
	trail.append(o + se * 13.0 + ne * 1.0)  # island
	t.apply(trail, "dirt")
	var patch: Array = []
	for i in range(1, 4):
		for j in range(7, 10):
			patch.append(o + se * float(i) + ne * float(j))
	t.apply(patch, "temple")
	var rocks: Array = []
	for i in range(12, 15):
		for j in range(8, 11):
			rocks.append(o + se * float(i) + ne * float(j))
	t.apply(rocks, "rock")
	var path_cells: Array = []
	for i in range(5, 8):
		for j in range(7, 10):
			path_cells.append(o + se * float(i) + ne * float(j))
	t.apply(path_cells, "ground")
	t.apply([o + se * 12.0 + ne * 1.0, o + se * 13.0 + ne * 2.0], "water")
	placed._changed(false)
	arena.editor.void_check = false
	arena.editor.set_open(true)
	var cam := arena.editor._camera()
	if cam != null:
		cam.offset += (o + se * 7.0 + ne * 5.0) - cam.get_screen_center_position()
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
