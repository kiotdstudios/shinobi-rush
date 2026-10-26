extends SceneTree
## Dev tool: the map editor page as the browser shows it. godot --path . --script res://tools/shot_map_editor.gd -- out.png [width height]

func _init() -> void:
	var out := "user://map_editor.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 2:
		root.size = Vector2i(int(args[1]), int(args[2]))
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
