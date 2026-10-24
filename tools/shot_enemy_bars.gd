extends SceneTree
## Dev tool: screenshot of the Bandit with its enemy bars. godot --path . --script res://tools/shot_enemy_bars.gd -- out.png

func _init() -> void:
	var out := "user://enemy_bars.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var bandits := arena.find_children("*", "Bandit", true, false)
	var b: Bandit = bandits[0] as Bandit if bandits.size() > 0 else null
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		cam.zoom = Vector2(2, 2)
		if b != null:
			cam.global_position = b.global_position + Vector2(0, -60)
			cam.reset_smoothing()
	if b != null:
		b.hp = b.max_hp * 0.7
		b.chakra = b.max_chakra * 0.6
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("bandits ", bandits.size())
	quit()
