extends SceneTree
## Dev tool: scripted walk around, up, over and back down the Ancient Flame Shrine in the RUNNING game (windowed).
## godot --path . --script res://tools/shot_shrine_climb.gd -- <out_dir> [every_n_ticks]
## Drives the real player through the move input actions, and saves a PNG every N physics ticks plus a log of the
## elevation / ground position. The ground position is what collision and sorting use; the figure is drawn higher.

const SE = preload("res://scripts/environment/shrine_elevation.gd")
var player: PlayerController
var shrine: DynamicShrine
var label: Label
var out_dir := "user://shrine_climb"
var every := 4
var tick := 0
var frame := 0
var log_lines: PackedStringArray = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		every = int(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	for o: Dictionary in placed.objects.duplicate():
		placed.remove(o, false)
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	player = get_first_node_in_group("player") as PlayerController
	var spot := (arena.get_node("Spawn") as Node2D).position
	var obj := placed.add("dynamic_shrine", spot + Vector2(0, 160), false)
	shrine = obj.nodes[0] as DynamicShrine
	var layer := CanvasLayer.new()
	layer.layer = 50
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	main.add_child(layer)
	player.camera.zoom = Vector2(1.25, 1.25)
	var mouth := SE.MOUTH
	var out_dir_v := (SE.MOUTH - SE.TOP).normalized()
	player.global_position = shrine.to_global(mouth + out_dir_v * 120.0 - SE.FOOT)
	player.reset_camera()
	for i in 20:
		await physics_frame
	var route := {
		"approach the stairs": [mouth + out_dir_v * 20.0],
		"climb": [SE.TOP, SE.PLATFORM_CENTER + Vector2(0, 28)],
		"circle the monument": [Vector2(345, 336), Vector2(352, 312), Vector2(335, 296), Vector2(285, 294), Vector2(255, 297), Vector2(226, 318), Vector2(238, 348), Vector2(285, 352)],
		"back to the stairs": [SE.TOP, mouth + out_dir_v * 10.0],
		"walk off": [mouth + out_dir_v * 110.0],
		"around the mound (east)": [Vector2(300, 520), Vector2(540, 430), Vector2(560, 330)],
		"around the mound (north)": [Vector2(470, 235), Vector2(272, 215), Vector2(80, 270)],
		"around the mound (west)": [Vector2(-10, 360), Vector2(70, 450), mouth + out_dir_v * 90.0],
	}
	for phase: String in route:
		for wp: Vector2 in route[phase]:
			await _goto(phase, wp)
	_release()
	for i in 20:
		await _step("done")
	var f := FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	quit()


func _art_pos() -> Vector2:
	return shrine.to_local(player.global_position) + SE.FOOT


func _step(phase: String) -> void:
	await physics_frame
	tick += 1
	label.text = "%s\nelevation %5.1f / %d    ground (%d, %d)    draw order: %s" % [phase, player.elevation, int(SE.HEIGHT),
		int(_art_pos().x), int(_art_pos().y), "upper" if shrine.sort_upper else "ground"]
	if tick % every == 0:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("f%04d.png" % frame))
		log_lines.append("%d,%s,%.1f,%.1f,%.1f,%s" % [frame, phase, player.elevation, _art_pos().x, _art_pos().y, shrine.sort_upper])
		frame += 1


func _goto(phase: String, target: Vector2, ticks: int = 900) -> void:
	for i in ticks:
		var d := target - _art_pos()
		if d.length() < 12.0:
			return
		_hold(d.normalized())
		await _step(phase)
	print("route: gave up before ", target, " at ", _art_pos())


func _hold(dir: Vector2) -> void:
	_release()
	if dir.x < 0.0:
		Input.action_press("move_left", -dir.x)
	if dir.x > 0.0:
		Input.action_press("move_right", dir.x)
	if dir.y < 0.0:
		Input.action_press("move_up", -dir.y)
	if dir.y > 0.0:
		Input.action_press("move_down", dir.y)


func _release() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
