extends SceneTree
## Dev tool: wide shot of the starting area. godot --path . --script res://tools/shot_start_area.gd -- out.png [zoom]

func _init() -> void:
	var out := "user://start_area.png"
	var zoom := 0.5
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		zoom = float(args[1])
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var sp := (arena.get_node("Spawn") as Node2D).position
	print("SPAWN ", sp, " BOUNDS ", arena.bounds)
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		cam.zoom = Vector2(zoom, zoom)
		cam.limit_left = -100000
		cam.limit_right = 100000
		cam.limit_top = -100000
		cam.limit_bottom = 100000
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
