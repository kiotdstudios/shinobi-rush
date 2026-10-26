extends SceneTree
## Dev tool: the Blightwood starting map, whole-map overview and a close-up of the courtyard.
## godot --path . --script res://tools/shot_blightwood_map.gd -- out_dir

func _init() -> void:
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.size = Vector2i(1672, 941)
	root.content_scale_size = Vector2i(1672, 941)
	BlightwoodMap.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.autosave = false
	print("objects: ", arena.placed.objects.size(), " applied: ", arena.placed.blightwood_map_applied)
	arena.editor.void_check = false
	arena.editor.set_open(true)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != null and n.get_parent() == arena.editor:
			(n as CanvasLayer).visible = false
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var cam := arena.editor._camera()
	if cam != null:
		cam.zoom = Vector2(0.4, 0.4)
		cam.offset = Vector2(0, 40) - cam.get_screen_center_position() + cam.offset
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("map_overview.png"))
	if cam != null:
		cam.zoom = Vector2(1.0, 1.0)
		cam.offset = Vector2(0, 0) - cam.get_screen_center_position() + cam.offset
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("map_courtyard.png"))
	quit()
