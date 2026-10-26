extends SceneTree
## Dev tool: Chidori charge in all 8 facings (hand anchor check). godot --path . --script res://tools/shot_chidori_dirs.gd -- out.png
func _init() -> void:
	var out := "user://chi_dirs.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.size = Vector2i(1280, 720)
	Bandit.substitution_enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	var arena := main.get_node("TrainingArena")
	var player := arena.get_node("Player") as PlayerController
	var b := arena.get_node_or_null("Bandit")
	if b != null:
		b.queue_free()
	var dirs := [Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1)]
	var sheet := Image.create(8 * 160, 160, false, Image.FORMAT_RGBA8)
	var i := 0
	for d: Vector2 in dirs:
		player.chakra = 100.0
		player.chidori_cd = 0.0
		player.facing = d.normalized()
		player.facing8 = d.normalized()
		player.use_jutsu("square")
		for f in 24:
			await physics_frame
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var c := Vector2i(640, 360)
		var vp := root.get_viewport().get_camera_2d()
		var sp := player.get_global_transform_with_canvas().origin
		var crop := img.get_region(Rect2i(Vector2i(sp) - Vector2i(80, 110), Vector2i(160, 160)))
		sheet.blit_rect(crop, Rect2i(0, 0, 160, 160), Vector2i(i * 160, 0))
		i += 1
		player._cancel_chidori()
		for f in 10:
			await physics_frame
	sheet.save_png(out)
	quit()
