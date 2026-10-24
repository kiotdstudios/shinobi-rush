extends SceneTree
## Dev tool: render trees + short/tall grass + fences in the real arena and save a PNG.
## godot --path . --script res://tools/shot_fences.gd -- C:/out.png   (needs a real renderer, not --headless)

func _init() -> void:
	var out := "user://fence_shot.png"
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
	for n in arena.find_children("*", "Camera2D", true, false):
		(n as Camera2D).zoom = Vector2(2, 2)
	var c: Vector2 = (arena.get_node("Spawn") as Node2D).position + Vector2(0, 100)
	for n in arena.find_children("*", "Camera2D", true, false):
		var cam := n as Camera2D
		c = cam.get_screen_center_position() + Vector2(0, 60)
	for r in range(-3, 5):
		for q in range(-5, 6):
			var p := c + Vector2(q * 72 + (36 if r % 2 != 0 else 0), r * 36 + 40)
			var tall := q >= 0
			placed.add("grass_tall_0%d" % ((q + r + 20) % 4) if tall else "grass9_center", p, false)
	placed.add("tree_1", c + Vector2(-230, -60), false)
	placed.add("tree_3", c + Vector2(240, -50), false)
	placed.add("tree_2", c + Vector2(0, -100), false)
	# a pen: back-left run SE, back-right run SW, front-left SW... corners meet at posts
	var top := c + Vector2(0, -20)
	placed.add("fence_se_4", top + Vector2(-180, 0) + Vector2(0, 0), false)
	placed.add("fence_sw_4", top + Vector2(180, 0), false)
	placed.add("fence_post_tall", top, false)
	placed.add("fence_se_2", c + Vector2(-60, 150), false)
	placed.add("fence_post", c + Vector2(12, 186), false)
	for i in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
