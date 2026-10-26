extends SceneTree
## Dev tool: a contact sheet of the lock-on animation on a real bandit (acquire, snap, locked, release).
## godot --path . --script res://tools/shot_lock_on.gd -- C:/out.png   (needs a real renderer, not --headless)

func _init() -> void:
	var out := "user://lock_on.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	AncientShrineSection.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.autosave = false
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var player: Node2D = get_first_node_in_group("player")
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	arena.add_child(bandit)
	bandit.global_position = player.global_position + Vector2(170, 40)
	bandit.set_physics_process(false)
	player.camera.zoom = Vector2(2.2, 2.2)
	var lock := player.get_node("LockOn") as PlayerLockOn
	var shots: Array[Image] = []
	var times := [0.0, 0.10, 0.20, 0.30, 0.40, 0.60, 1.0, 1.35]
	for i in 3:
		await process_frame
	lock.toggle()
	var t := 0.0
	for k in times.size():
		while t < times[k]:
			await process_frame
			t += 1.0 / 60.0
		var img := root.get_viewport().get_texture().get_image()
		shots.append(img)
	lock.toggle()
	var rel := [0.05, 0.14]
	t = 0.0
	for r in rel:
		while t < r:
			await process_frame
			t += 1.0 / 60.0
		shots.append(root.get_viewport().get_texture().get_image())
	var sz := shots[0].get_size()
	var bx := bandit.get_global_transform_with_canvas().origin
	var w := 360
	var h := 420
	var sheet := Image.create(w * 5, h * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in shots.size():
		var rect := Rect2i(int(bx.x) - w / 2, int(bx.y) - h / 2 - 70, w, h)
		rect = rect.intersection(Rect2i(Vector2i.ZERO, sz))
		sheet.blit_rect(shots[i], rect, Vector2i((i % 5) * w, (i / 5) * h))
	sheet.save_png(out)
	quit()
