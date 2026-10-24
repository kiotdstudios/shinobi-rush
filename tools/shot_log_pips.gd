extends SceneTree
## Dev tool: log-pip animation frames. godot --path . --rendering-driver opengl3 --script res://tools/shot_log_pips.gd -- out_prefix
func _init() -> void:
	var out := "user://log_pips"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var hud: HealthBar = null
	for n in main.find_children("*", "HealthBar", true, false):
		hud = n as HealthBar
	var b: Bandit = arena.find_children("*", "Bandit", true, false)[0] as Bandit
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		cam.zoom = Vector2(2, 2)
		cam.global_position = b.global_position + Vector2(0, -60)
		cam.reset_smoothing()
	b.set_physics_process(false)
	b.visual.set_process(false)
	b.substitutions = 1
	var ages := [0.22, 0.45, 0.7]
	for k in ages.size():
		b.sub_use_age = [-1.0, ages[k]] as Array[float]
		b.visual.queue_redraw()
		if hud != null:
			hud.use_age = [-1.0, ages[k], -1.0] as Array[float]
			hud.pips = 1
			hud._redraw()
		hud.set_process(false)
		for i in 3:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, k])
	b.chakra = 15.0
	b.is_charging_chakra = true
	b.sub_use_age = [-1.0, -1.0] as Array[float]
	b.visual.queue_redraw()
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s_charge.png" % out)
	quit()
