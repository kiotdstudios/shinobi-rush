extends SceneTree
## Dev tool: Chidori vs Paper Bomb at identical zoom/background, plus charge/rush/impact strips.
## godot --path . --script res://tools/shot_chidori.gd -- out_prefix
var prefix := "user://chi"

func _grab(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, name])

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
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
	var cam := root.get_viewport().get_camera_2d()
	var c := player.global_position
	# side by side: paper left, chidori right
	var pp := c + Vector2(-190, 40)
	var cp := c + Vector2(190, 40)
	var bomb := PaperTagBomb.spawn(arena, pp, Vector2.RIGHT, player)
	bomb.set_physics_process(false)
	bomb.explode()
	var ch := ChidoriImpact.spawn(arena, cp, Vector2.RIGHT)
	ch.set_process(false)
	var t := 0.0
	var marks := [0.04, 0.09, 0.16, 0.30, 0.45]
	var idx := 0
	for m: float in marks:
		var step: float = m - t
		bomb.advance(step)
		ch.advance(step)
		t = m
		await _grab("sbs_%02d" % int(m * 100))
	bomb.queue_free()
	ch.queue_free()
	await process_frame
	# real in-game use
	player.chakra = 100.0
	player.facing = Vector2.RIGHT
	player.use_jutsu("square")
	var n := 0
	var frame := 0
	while frame < 126:
		await physics_frame
		frame += 1
		if frame % 3 == 0:
			await _grab("live_%03d" % frame)
	quit()
