extends SceneTree
## Dev tool: the two bandit crews side by side. godot --path . --rendering-driver opengl3 --script res://tools/shot_bandit_crews.gd -- out.png
func _init() -> void:
	var out := "user://bandit_crews.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	BlightwoodMap.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var red := arena.get_node("Bandit") as Bandit
	var packed := load("res://scenes/enemy/bandit.tscn") as PackedScene
	var jade := packed.instantiate() as Bandit
	jade.crew_id = 1
	arena.add_child(jade)
	jade.global_position = red.global_position + Vector2(240, 0)
	for b in [red, jade]:
		(b as Bandit).set_physics_process(false)
		(b as Bandit).facing8 = Vector2.DOWN
	jade.drinking = "health"
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		cam.zoom = Vector2(2.2, 2.2)
		cam.global_position = red.global_position + Vector2(120, -60)
		cam.reset_smoothing()
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
