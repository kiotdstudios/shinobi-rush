extends RefCounted
## Ancient Flame Shrine elevation: staircase, platform, depth layers and collision, driven through the real player.

const SE = preload("res://scripts/environment/shrine_elevation.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var ck: Callable
var root: Node
var tree: SceneTree
var shrine: DynamicShrine
var player: PlayerController
var max_step := 0.0
var min_step := 0.0


func run(p_ck: Callable, p_root: Node) -> void:
	ck = p_ck
	root = p_root
	tree = root.get_tree()
	_geometry()
	_layers()
	await _in_game()


func _art(local: Vector2) -> Vector2:
	return local + SE.FOOT


func _world(art: Vector2) -> Vector2:
	return shrine.to_global(art - SE.FOOT)


func _art_pos() -> Vector2:
	return _art(shrine.to_local(player.global_position))


func _geometry() -> void:
	var run_vec := SE.TOP - SE.MOUTH
	var prev := -1.0
	var worst := 0.0
	var monotone := true
	for i in 81:
		var e := SE.elevation_at(SE.MOUTH + run_vec * (float(i) / 80.0) - SE.FOOT)
		if prev >= 0.0:
			worst = maxf(worst, absf(e - prev))
			monotone = monotone and e >= prev - 0.0001
		prev = e
	ck.call("elevation: starts at the ground at the stair mouth", is_zero_approx(SE.elevation_at(SE.MOUTH - SE.FOOT)))
	ck.call("elevation: reaches the platform height at the top step", is_equal_approx(prev, SE.HEIGHT))
	ck.call("elevation: climbing never lowers it", monotone)
	ck.call("elevation: gradual, no jump between samples (%.2f px max)" % worst, worst < SE.HEIGHT / 10.0)
	var row_a := SE.elevation_at(SE.MOUTH + run_vec * 0.5 - SE.FOOT)
	var row_b := SE.elevation_at(SE.MOUTH + run_vec * 0.5 + SE.STAIR_HALF * 0.8 - SE.FOOT)
	var row_c := SE.elevation_at(SE.MOUTH + run_vec * 0.5 - SE.STAIR_HALF * 0.8 - SE.FOOT)
	ck.call("elevation: every step is level across its width", is_equal_approx(row_a, row_b) and is_equal_approx(row_a, row_c))
	ck.call("elevation: platform is flat at full height", is_equal_approx(SE.elevation_at(SE.PLATFORM_CENTER - SE.FOOT), SE.HEIGHT))
	var outside := true
	for p: Vector2 in [Vector2(-300, -100), Vector2(300, -60), Vector2(0, 80), Vector2(0, -260), Vector2(-150, -40)]:
		outside = outside and is_zero_approx(SE.elevation_at(p))
	ck.call("elevation: zero everywhere else on the ground", outside)
	var key_ok := true
	for x in range(0, 544, 8):
		key_ok = key_ok and SE.front_edge_y(float(x)) >= 360.0 and SE.front_edge_y(float(x)) <= 455.0
	ck.call("depth: front edge keys stay on the mound", key_ok and is_equal_approx(SE.front_edge_y(272.0), 455.0))


func _layers() -> void:
	var base := Image.load_from_file(ProjectSettings.globalize_path(DynamicShrine.DIR + "stone.png"))
	base.convert(Image.FORMAT_RGBA8)
	var data := base.get_data()
	var covered := PackedByteArray()
	covered.resize(544 * 480)
	var exact := true
	var overlaps := 0
	for layer in DynamicShrine.LAYERS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DynamicShrine.DIR + "stone_%s.png" % layer))
		img.convert(Image.FORMAT_RGBA8)
		var d := img.get_data()
		for i in 544 * 480:
			if d[i * 4 + 3] == 0:
				continue
			if covered[i] != 0:
				overlaps += 1
			covered[i] = 1
			for c in 4:
				if d[i * 4 + c] != data[i * 4 + c]:
					exact = false
	var missing := 0
	for i in 544 * 480:
		if data[i * 4 + 3] != 0 and covered[i] == 0:
			missing += 1
	ck.call("layers: the depth layers recomposite to the shrine art exactly", exact and overlaps == 0 and missing == 0)


func _hold(dir: Vector2) -> void:
	for a: String in ACTIONS:
		Input.action_release(a)
	if dir.x < 0.0:
		Input.action_press("move_left", -dir.x)
	if dir.x > 0.0:
		Input.action_press("move_right", dir.x)
	if dir.y < 0.0:
		Input.action_press("move_up", -dir.y)
	if dir.y > 0.0:
		Input.action_press("move_down", dir.y)


func _release() -> void:
	_hold(Vector2.ZERO)


func _tick() -> void:
	var before := player.elevation
	await tree.physics_frame
	var d := player.elevation - before
	max_step = maxf(max_step, d)
	min_step = minf(min_step, d)


## Walk the player toward an art-space point until within `reach`; true if it got there.
func _goto(target: Vector2, ticks: int = 400, reach: float = 7.0) -> bool:
	for i in ticks:
		var d := target - _art_pos()
		if d.length() < reach:
			_release()
			return true
		_hold(d.normalized())
		await _tick()
	_release()
	return false


func _teleport(art: Vector2) -> void:
	player.global_position = _world(art)
	player.velocity = Vector2.ZERO
	player.elevation = SE.target_at(player.global_position)
	await tree.physics_frame
	await tree.physics_frame


func _blocked(from_art: Vector2, motion: Vector2) -> bool:
	return player.test_move(Transform2D(0.0, _world(from_art)), motion)


func _in_game() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	player = tree.get_first_node_in_group("player") as PlayerController
	for e in tree.get_nodes_in_group("enemy"):
		e.queue_free()
	var placed := arena.placed
	placed.autosave = false
	var obj := placed.add("dynamic_shrine", Vector2(1000, 900), false)
	shrine = obj.nodes[0] as DynamicShrine
	shrine.set_process(false)
	for c in arena.get_children():
		if c is StaticBody2D and c != shrine and c.global_position.distance_to(shrine.global_position) < 800.0 and not shrine.is_ancestor_of(c):
			c.queue_free()
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	ck.call("shrine: registered as an elevation zone with ground, solid and edge bodies",
		SE.zones.has(shrine) and shrine.ground_body != null and shrine.edge_body != null)
	# Collision from all four directions at ground level (clear of the stair mouth).
	var mound_ok := true
	var sides := {
		"south": [Vector2(380, 470), Vector2(0, -60)],
		"west": [Vector2(-30, 361), Vector2(120, 0)],
		"east": [Vector2(540, 360), Vector2(-120, 0)],
		"north": [Vector2(300, 200), Vector2(0, 110)],
	}
	for side: String in sides:
		var b := _blocked(sides[side][0], sides[side][1])
		ck.call("collision: the mound blocks from the %s" % side, b)
		mound_ok = mound_ok and b
	var mouth_dir := (SE.TOP - SE.MOUTH).normalized()
	ck.call("collision: the stair entrance is open", not _blocked(SE.MOUTH - mouth_dir * 70.0, mouth_dir * 60.0))

	# Stair sides stop the player at the bottom half (ground mask) and the top half (upper level).
	var run_vec := SE.TOP - SE.MOUTH
	for t: float in [0.3, 0.8]:
		for side: float in [-1.0, 1.0]:
			await _teleport(SE.MOUTH + run_vec * t)
			var run_n := run_vec.normalized()
			var cross := Vector2(-run_n.y, run_n.x)
			if cross.dot(SE.STAIR_HALF * side) < 0.0:
				cross = -cross
			for i in 60:
				_hold(cross)
				await tree.physics_frame
			_release()
			var lp0 := shrine.to_local(player.global_position)
			var inside := SE.in_stairs(lp0) or SE.in_platform(lp0)
			ck.call("stairs: the %s side wall holds at t=%.1f" % ["right" if side > 0.0 else "left", t], inside)
	# Approach, climb, reach the platform: elevation rises gradually and never teleports.
	await _teleport(SE.MOUTH - mouth_dir * 70.0)
	ck.call("climb: starts on the ground", is_zero_approx(player.elevation) and not shrine.sort_upper)
	max_step = 0.0
	min_step = 0.0
	var reached := await _goto(SE.TOP + mouth_dir * 20.0, 400)
	ck.call("climb: walks up the stairs to the top step", reached)
	ck.call("climb: elevation rose gradually (max %.2f px/tick)" % max_step, max_step > 0.5 and max_step <= SE.RATE / 60.0 + 0.01 and min_step >= -0.01)
	for i in 30:
		await tree.physics_frame
	ck.call("climb: on the platform at full height", is_equal_approx(player.elevation, SE.HEIGHT))
	ck.call("climb: the figure is drawn higher by the elevation", is_equal_approx(player.visual.position.y, -SE.HEIGHT))
	ck.call("climb: the camera follows the raised figure", is_equal_approx(player.camera.position.y, -SE.HEIGHT))
	ck.call("climb: ground collision is ignored and the mound sorts behind the player",
		player.get_collision_exceptions().has(shrine.ground_body) and shrine.sort_upper)
	ck.call("climb: ground position is unchanged by height (feet stay on the ground plane)",
		SE.in_platform(shrine.to_local(player.global_position)))

	# Platform: the monument and rim are solid, and the player can circle the monument.
	var mon_c: Vector2 = SE.MONUMENT[0]
	await _teleport(Vector2(mon_c.x, mon_c.y + 60.0))
	for i in 90:
		_hold(Vector2(0, -1))
		await tree.physics_frame
	_release()
	var stop_y := _art_pos().y
	ck.call("platform: the monument blocks from the south (stopped at y=%.0f)" % stop_y, stop_y > mon_c.y + 5.0)
	var ring: Array[Vector2] = [Vector2(285, 352), Vector2(345, 336), Vector2(352, 312), Vector2(335, 296), Vector2(285, 294), Vector2(255, 297), Vector2(226, 318), Vector2(238, 348), Vector2(285, 352)]
	var loop_ok := true
	await _teleport(Vector2(285, 340))
	for wp in ring:
		var got := await _goto(wp, 260, 10.0)
		if not got:
			print("  loop stuck before ", wp, " at ", _art_pos(), " elev ", player.elevation, " cols ", player.get_slide_collision_count(), " ", [player.get_slide_collision(0).get_collider().name, player.get_slide_collision(0).get_normal()] if player.get_slide_collision_count() > 0 else "")
		loop_ok = loop_ok and got
	ck.call("platform: the player walks all the way around the monument", loop_ok)
	for dir: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
		await _teleport(SE.PLATFORM_CENTER + Vector2(0, 30))
		for i in 150:
			_hold(dir)
			await tree.physics_frame
		_release()
		var lp := shrine.to_local(player.global_position)
		ck.call("platform: the rim stops the player walking off toward %s" % [dir], SE.in_platform(lp) and is_equal_approx(player.elevation, SE.HEIGHT))

	# Abilities still work while raised.
	await _teleport(SE.PLATFORM_CENTER + Vector2(0, 30))
	Input.action_press("attack_light")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release("attack_light")
	var attacked := player.state in [PlayerController.State.LIGHT1, PlayerController.State.LIGHT2, PlayerController.State.LIGHT3]
	ck.call("abilities: a light attack works on the platform and keeps the height", attacked and is_equal_approx(player.visual.position.y, -SE.HEIGHT))
	for i in 90:
		await tree.physics_frame
	var kunai := PlayerKunai.spawn(arena, player.global_position + Vector2(0, -5), Vector2(1, 0), player)
	for i in 10:
		kunai.step(1.0 / 60.0)
	ck.call("abilities: a kunai thrown from the platform is not swallowed by the mound or rim", kunai.hit_result == "")
	var ground_spot := _world(Vector2(300, 440))
	ck.call("abilities: substitution refuses a spot on another level", not player._substitution_spot_ok(ground_spot))

	# Descend smoothly.
	max_step = 0.0
	min_step = 0.0
	var down := await _goto(SE.MOUTH - mouth_dir * 60.0, 700)
	ck.call("descend: walks back down the stairs to the ground", down)
	ck.call("descend: elevation fell gradually (min %.2f px/tick)" % min_step, min_step < -0.5 and min_step >= -SE.RATE / 60.0 - 0.01 and max_step <= 0.01)
	for i in 30:
		await tree.physics_frame
	ck.call("descend: back at ground level, normal collision and sorting", is_zero_approx(player.elevation) and not shrine.sort_upper
		and not player.get_collision_exceptions().has(shrine.ground_body) and is_zero_approx(player.visual.position.y) and is_zero_approx(player.camera.position.y))
	# Depth order around the shrine.
	var base_key := 0.0
	var mon_key := 0.0
	for sl in shrine.slices:
		if sl.name.ends_with("_base") and base_key == 0.0:
			base_key = sl.position.y
		if sl.name.ends_with("_mon") and mon_key == 0.0:
			mon_key = sl.position.y
	ck.call("depth: at ground level the mound's slices sit on its sloped front edge", base_key < 10.0 and base_key > -100.0)
	shrine.set_sort_upper(true)
	var upper_base := -1.0e9
	for sl in shrine.slices:
		if sl.name.ends_with("_base"):
			upper_base = maxf(upper_base, sl.position.y)
	ck.call("depth: on the upper level the base is behind any actor, the monument sorts at its own foot", upper_base < -1000.0 and absf(shrine.slices.filter(func(s: DynamicShrine.Slice): return s.name.ends_with("_mon"))[0].position.y - (312.0 - SE.FOOT.y)) < 0.01)
	shrine.set_sort_upper(false)
	placed.remove(obj, false)
	await tree.process_frame
	ck.call("shrine: removing it unregisters the zone", not SE.zones.has(shrine) or not is_instance_valid(shrine))
	main.queue_free()
