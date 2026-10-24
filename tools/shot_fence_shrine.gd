extends SceneTree
## Dev tool: shrine with a fence passing in front of it (sort check). godot --path . --script res://tools/shot_fence_shrine.gd -- out.png

func _init() -> void:
	var out := "user://fence_shrine.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	for o: Dictionary in placed.objects.duplicate():
		placed.remove(o, false)
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var c := (arena.get_node("Spawn") as Node2D).position
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		cam.zoom = Vector2(2, 2)
		c = cam.get_screen_center_position()
	placed.add("ancient_shrine", c, false)
	for k in 3:
		placed.add("fence_se_2", c + Vector2(-216 + k * 144, -108 + 20 + k * 72 + 40), false)
	placed.add("fence_sw_2", c + Vector2(100, 10), false)
	placed.add("fence_se_3", c + Vector2(-200, 10), false)
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
