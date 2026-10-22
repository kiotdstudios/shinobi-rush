extends RefCounted
## Jump-launch regression (P0, 2026-10-20: "jumping launches player super far"). Measures real world
## displacement + horizontal speed across jump variants and checks they stay bounded. Every scenario also
## prints a `MEASURE ...` line so before/after numbers can be pulled from the test log.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	await test_variant(tree_root, "standing", "", false, false)
	await test_variant(tree_root, "walk", "move_right", false, false)
	await test_variant(tree_root, "run_sprint", "move_right", true, false)
	await test_variant(tree_root, "sprint_air_attack", "move_right", true, true)
	await test_variant(tree_root, "walk_air_attack", "move_right", false, true)
	await test_direction_change(tree_root)
	await test_dodge_then_jump(tree_root)
	await test_repeated_jumps(tree_root)
	# test_tick_rate_independent() (30/60/120 Hz) is run manually only: changing Engine.physics_ticks_per_second
	# mid-suite wedged the headless runner intermittently, which is unacceptable in CI.


func _boot(tree_root: Node) -> Array:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	return [main, main.get_node_or_null("TrainingArena/Player") as PlayerController]


func _reset(p: PlayerController, pos: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)
	p._dodge_buffer = 0.0
	p._jump_buffer = 0.0
	p._attack_buffer = 0.0
	p._attack_timer = 0.0
	p._hitstop_timer = 0.0
	p._combo_index = 0
	p._dash_grace_timer = 0.0
	p.state = PlayerController.State.IDLE
	p.global_position = pos
	p.velocity = Vector2.ZERO


func _tap(action: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Input.action_press(action)
	for i in 3:
		await tree.physics_frame
	Input.action_release(action)


func _airborne(p: PlayerController) -> bool:
	return p.state == PlayerController.State.JUMP or p.state == PlayerController.State.AIR_ATTACK


## Runs one jump already started; returns {disp, peak, late_peak, ticks, end_speed}. late_peak ignores the
## first 0.3 s (the brake-down window for entry speed above the cap).
func _measure_jump(p: PlayerController, tree: SceneTree, start: Vector2, attack_at: int) -> Dictionary:
	var peak := 0.0
	var late_peak := 0.0
	var ticks := 0
	while _airborne(p) and ticks < 600:
		if attack_at > 0 and ticks == attack_at:
			await _tap("attack_light")
			ticks += 3
			continue
		await tree.physics_frame
		ticks += 1
		if not _airborne(p):
			break  # the landing frame applies ground accel; not air motion
		var sp := p.velocity.length()
		peak = maxf(peak, sp)
		if float(ticks) / Engine.physics_ticks_per_second > 0.3:
			late_peak = maxf(late_peak, sp)
	return {"disp": p.global_position.distance_to(start), "peak": peak, "late_peak": late_peak,
		"ticks": ticks, "end_speed": p.velocity.length()}


func test_variant(tree_root: Node, label: String, dir: String, sprint: bool, attack: bool) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var p: PlayerController = r[1]
	var tree := main.get_tree()
	await _reset(p, Vector2(-1200, 100))
	if dir != "":
		Input.action_press(dir)
	if sprint:
		Input.action_press("sprint")
	for i in 40:
		await tree.physics_frame
	var pre_speed := p.velocity.length()
	var start := p.global_position
	await _tap("jump")
	var jumped := p.state == PlayerController.State.JUMP
	var m: Dictionary = await _measure_jump(p, tree, start, 12 if attack else 0)
	print("MEASURE %s pre_speed=%.1f peak_speed=%.1f late_peak=%.1f disp=%.1f ticks=%d" % [label, pre_speed, m.peak, m.late_peak, m.disp, m.ticks])
	var bound: float = 0.5 * WorldScale.WALK_SPEED * (m.ticks / 60.0) + 120.0  # cap x duration + brake-down slack
	ck.call("jump[%s]: jump started" % label, jumped, p.get_state_name())
	ck.call("jump[%s]: displacement bounded (%.0f <= %.0f)" % [label, m.disp, bound], m.disp <= bound)
	ck.call("jump[%s]: speed after brake window <= air cap" % label, m.late_peak <= p.jump_air_speed_cap + 1.0, str(m.late_peak))
	if dir == "":
		ck.call("jump[%s]: standing jump stays put (%.1f px)" % [label, m.disp], m.disp < 5.0)
	if dir != "":
		Input.action_release(dir)
	Input.action_release("sprint")
	main.queue_free()


func test_direction_change(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var p: PlayerController = r[1]
	var tree := main.get_tree()
	await _reset(p, Vector2(-1200, 100))
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 40:
		await tree.physics_frame
	var start := p.global_position
	await _tap("jump")
	Input.action_release("move_right")
	Input.action_press("move_left")
	var ticks := 0
	var peak := 0.0
	var turned := false
	while _airborne(p) and ticks < 600:
		await tree.physics_frame
		ticks += 1
		if not _airborne(p):
			break
		if ticks > 18:
			peak = maxf(peak, p.velocity.length())
		if p.velocity.x < 0.0:
			turned = true
	print("MEASURE direction_change peak_after_brake=%.1f disp=%.1f turned=%s" % [peak, p.global_position.distance_to(start), str(turned)])
	ck.call("jump[direction change]: steers (velocity reverses), no snap", turned)
	ck.call("jump[direction change]: speed stays <= cap", peak <= p.jump_air_speed_cap + 1.0, str(peak))
	ck.call("jump[direction change]: displacement bounded", p.global_position.distance_to(start) <= 0.5 * WorldScale.WALK_SPEED * 2.1 + 120.0)
	Input.action_release("move_left")
	Input.action_release("sprint")
	main.queue_free()


func test_dodge_then_jump(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var p: PlayerController = r[1]
	var tree := main.get_tree()
	await _reset(p, Vector2(-1200, 100))
	Input.action_press("move_right")
	for i in 30:
		await tree.physics_frame
	await _tap("dodge")
	var guard := 0
	while p.state == PlayerController.State.DODGE and p._action_timer > 0.06 and guard < 120:
		await tree.physics_frame
		guard += 1
	var entry_speed := p.velocity.length()
	var start := p.global_position
	await _tap("jump")
	var guard2 := 0
	while p.state != PlayerController.State.JUMP and guard2 < 30:
		await tree.physics_frame
		guard2 += 1
	var m: Dictionary = await _measure_jump(p, tree, start, 0)
	print("MEASURE dodge_then_jump entry_speed=%.1f peak=%.1f late_peak=%.1f disp=%.1f ticks=%d" % [entry_speed, m.peak, m.late_peak, m.disp, m.ticks])
	ck.call("jump[dodge->jump]: dodge burst does not persist (late peak <= cap)", m.late_peak <= p.jump_air_speed_cap + 1.0, str(m.late_peak))
	ck.call("jump[dodge->jump]: displacement bounded", m.disp <= 0.5 * WorldScale.WALK_SPEED * (m.ticks / 60.0) + 160.0, str(m.disp))
	Input.action_release("move_right")
	main.queue_free()


func test_repeated_jumps(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var p: PlayerController = r[1]
	var tree := main.get_tree()
	await _reset(p, Vector2(-1500, 100))
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 40:
		await tree.physics_frame
	var start := p.global_position
	var total_ticks := 0
	var worst_late := 0.0
	for n in 3:
		await _tap("jump")
		var m: Dictionary = await _measure_jump(p, tree, p.global_position, 0)
		total_ticks += m.ticks + 3
		worst_late = maxf(worst_late, m.late_peak)
		for i in 4:
			await tree.physics_frame
			total_ticks += 1
	var disp: float = p.global_position.distance_to(start)
	print("MEASURE repeated_jumps x3 disp=%.1f worst_late_peak=%.1f ticks=%d" % [disp, worst_late, total_ticks])
	ck.call("jump[repeated x3]: speed never stacks above cap", worst_late <= p.jump_air_speed_cap + 1.0, str(worst_late))
	ck.call("jump[repeated x3]: displacement bounded by cap x time", disp <= 0.5 * WorldScale.WALK_SPEED * (total_ticks / 60.0) + 360.0, str(disp))
	Input.action_release("move_right")
	Input.action_release("sprint")
	main.queue_free()


func test_tick_rate_independent(tree_root: Node) -> void:
	var saved := Engine.physics_ticks_per_second
	var results := []
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		var r := await _boot(tree_root)
		var main: Node = r[0]
		var p: PlayerController = r[1]
		var tree := main.get_tree()
		await _reset(p, Vector2(-1200, 100))
		Input.action_press("move_right")
		Input.action_press("sprint")
		for i in int(hz * 0.7):
			await tree.physics_frame
		var start := p.global_position
		Input.action_press("jump")
		for i in 3:
			await tree.physics_frame
		Input.action_release("jump")
		var m: Dictionary = await _measure_jump(p, tree, start, 0)
		print("MEASURE tickrate_%d sprint_jump disp=%.1f peak=%.1f" % [hz, m.disp, m.peak])
		results.append(m.disp)
		Input.action_release("move_right")
		Input.action_release("sprint")
		main.queue_free()
		await tree_root.get_tree().process_frame
	Engine.physics_ticks_per_second = saved
	var lo: float = results.min()
	var hi: float = results.max()
	ck.call("jump[tick rate]: sprint-jump displacement within 25%% across 30/60/120 Hz (%.0f..%.0f)" % [lo, hi], hi - lo <= 0.25 * hi)
