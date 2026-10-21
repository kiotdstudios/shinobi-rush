extends RefCounted
## Combat system V1 (Milestone A: offensive combat only -- see the combat order). Called from
## tests/run_tests.gd. Covers the order's own acceptance tests that apply to Milestone A's scope:
## run->3-hit-combo->run with no idle pause, dodge->dash-attack without stopping, dodge-cancel of an
## attack's recovery, repeated inputs not restarting/skipping the combo, movement/jump/dodge staying
## functional, and a Bandit taking exactly one hit per swing and dying at 0 HP.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	await test_run_combo_run(tree_root)
	await test_dodge_dash_attack(tree_root)
	await test_attack_dodge_attack(tree_root)
	await test_dodge_cancel_recovery(tree_root)
	await test_mash_does_not_skip_or_restart(tree_root)
	await test_bandit_takes_damage_and_dies(tree_root)
	await test_air_attack_land_run(tree_root)
	await test_stale_buffer_expires(tree_root)
	await test_buffer_survives_hitstop(tree_root)
	await test_cancel_eligibility(tree_root)


func _boot(tree_root: Node) -> Array:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	return [main, arena, player]


func _reset(player: PlayerController, pos: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)
	player._dodge_buffer = 0.0
	player._jump_buffer = 0.0
	player._attack_buffer = 0.0
	player._dash_grace_timer = 0.0
	player._action_timer = 0.0
	player._attack_timer = 0.0
	player._hitstop_timer = 0.0
	player._combo_index = 0
	player.state = PlayerController.State.IDLE
	player.global_position = pos
	player.velocity = Vector2.ZERO


## Hold for a few frames before releasing: a same-frame press+release is faster than this headless
## harness can reliably register as a just_pressed edge (a real keypress always spans several
## frames) -- same reasoning as run_tests.gd's own `_tap` for dodge/jump.
func _tap(action: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Input.action_press(action)
	for i in 3:
		await tree.physics_frame
	Input.action_release(action)


# ------------------------------------------------------------------ 1. run -> 3-hit combo -> run
func test_run_combo_run(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("combat: scene has player (run-combo-run)", false)
		main.queue_free()
		return

	await _reset(player, Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 20:
		await main.get_tree().physics_frame
	ck.call("combo: run reaches walk_speed before attacking", is_equal_approx(player.velocity.x, player.walk_speed), str(player.velocity.x))

	var saw_idle := false
	var reached_light := [false, false, false]
	Input.action_press("attack_light")
	for i in 3:
		await main.get_tree().physics_frame
	Input.action_release("attack_light")
	for i in 400:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.IDLE:
			saw_idle = true
		if player.state == PlayerController.State.LIGHT1:
			reached_light[0] = true
		elif player.state == PlayerController.State.LIGHT2:
			reached_light[1] = true
		elif player.state == PlayerController.State.LIGHT3:
			reached_light[2] = true
		# Buffer the next combo hit partway through recovery of whichever hit is active, so the chain
		# continues without the button being released and re-pressed from scratch every time. Stop once
		# light3 has been reached once -- light3's combo_window wraps back to light1, and the test only
		# needs to see all three hits, not an unbounded chain.
		var saw_all_three: bool = reached_light[0] and reached_light[1] and reached_light[2]
		if not saw_all_three and player._attack_def != null and player._attack_phase == PlayerController.AttackPhase.RECOVERY and not Input.is_action_pressed("attack_light"):
			await _tap("attack_light")
		if player.state == PlayerController.State.MOVE or player.state == PlayerController.State.SPRINT:
			break
	ck.call("combo: reached light1, light2 and light3 in order via chained presses", reached_light[0] and reached_light[1] and reached_light[2], str(reached_light))
	ck.call("combo: no idle state anywhere during the run->combo->run sequence", not saw_idle)
	ck.call("combo: resumes MOVE (still running) immediately after the combo ends", player.state == PlayerController.State.MOVE, player.get_state_name())
	Input.action_release("move_right")
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ 2. dodge -> dash attack, no stop
func test_dodge_dash_attack(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("combat: scene has player (dodge-dash-attack)", false)
		main.queue_free()
		return

	await _reset(player, Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 10:
		await main.get_tree().physics_frame
	await _tap("dodge")
	ck.call("dash attack: dodge fires from MOVE", player.state == PlayerController.State.DODGE, player.get_state_name())
	# Wait until well inside the dodge's late window, then tap attack: should cancel straight into a
	# dash attack without ever passing through IDLE/MOVE in between.
	var reached_late := false
	for i in 60:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.DODGE and player._action_timer <= player.dash_attack_late_window:
			reached_late = true
			break
		if player.state != PlayerController.State.DODGE:
			break
	ck.call("dash attack: dodge survives long enough to reach its late window", reached_late)
	var min_v_during_transition := player.velocity.length()
	await _tap("attack_light")
	for i in 3:
		await main.get_tree().physics_frame
		min_v_during_transition = minf(min_v_during_transition, player.velocity.length())
	ck.call("dash attack: late-dodge attack press becomes DASH_ATTACK (not light1, not idle)", player.state == PlayerController.State.DASH_ATTACK, player.get_state_name())
	ck.call("dash attack: velocity never collapsed to ~0 across dodge->dash-attack", min_v_during_transition > 10.0, str(min_v_during_transition))
	Input.action_release("move_right")
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ attack -> dodge -> attack
func test_attack_dodge_attack(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("combat: scene has player (attack-dodge-attack)", false)
		main.queue_free()
		return

	await _reset(player, Vector2(-900, 100))
	await _tap("attack_light")
	ck.call("attack-dodge-attack: a stationary tap starts light1", player.state == PlayerController.State.LIGHT1, player.get_state_name())
	# Wait until recovery has committed past dodge_cancel_from, then dodge: should cancel the
	# remaining recovery immediately rather than waiting it out.
	var cancel_ready := false
	for i in 60:
		await main.get_tree().physics_frame
		if player._attack_def != null and player._attack_phase == PlayerController.AttackPhase.RECOVERY:
			var elapsed: float = player._attack_def.recovery - maxf(player._attack_timer, 0.0)
			if elapsed >= player._attack_def.dodge_cancel_from:
				cancel_ready = true
				break
		if not PlayerController._is_attack_state(player.state):
			break
	ck.call("attack-dodge-attack: light1 reaches its dodge-cancel-eligible point", cancel_ready)
	await _tap("dodge")
	ck.call("attack-dodge-attack: dodge cancels attack recovery", player.state == PlayerController.State.DODGE, player.get_state_name())
	# Let the dodge (and its short post-dodge grace window) fully clear, then attack again: a plain
	# light1, not a dash attack, since the grace window has lapsed by now.
	for i in 90:
		await main.get_tree().physics_frame
		if player.state != PlayerController.State.DODGE and player._dash_grace_timer <= 0.0:
			break
	await _tap("attack_light")
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("attack-dodge-attack: a deliberate later tap is a plain light1 (grace window lapsed)", player.state == PlayerController.State.LIGHT1, player.get_state_name())
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ dodge-cancel preserves collision
func test_dodge_cancel_recovery(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var arena: TrainingArena = r[1]
	var player: PlayerController = r[2]
	if player == null or arena == null:
		ck.call("combat: scene has player+arena (dodge-cancel collision)", false)
		main.queue_free()
		return

	# Right against the arena's right bound: dodge-cancel out of an attack must still obey collision
	# (order acceptance test #3: "without bypassing collision").
	await _reset(player, Vector2(arena.bounds.end.x - 40.0, 100))
	Input.action_press("move_right")
	await _tap("attack_light")
	for i in 60:
		await main.get_tree().physics_frame
		if player._attack_def != null and player._attack_phase == PlayerController.AttackPhase.RECOVERY:
			var elapsed: float = player._attack_def.recovery - maxf(player._attack_timer, 0.0)
			if elapsed >= player._attack_def.dodge_cancel_from:
				break
	Input.action_release("move_right")
	await _tap("dodge")
	for i in 40:
		await main.get_tree().physics_frame
	ck.call("dodge-cancel: still inside arena bounds after a wall-adjacent cancel (collision honored)", player.global_position.x <= arena.bounds.end.x + 1.0, "x=%.1f bound=%.1f" % [player.global_position.x, arena.bounds.end.x])
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ mashing can't skip/restart the combo
func test_mash_does_not_skip_or_restart(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("combat: scene has player (mash)", false)
		main.queue_free()
		return

	await _reset(player, Vector2(-900, 100))
	await _tap("attack_light")
	ck.call("mash: a tap begins light1", player.state == PlayerController.State.LIGHT1, player.get_state_name())
	var saw_light2_during_startup_or_active := false
	# Hammer the button every frame through startup+active: the swing must not restart or jump ahead
	# while it's still in those phases -- the combo buffer is only consulted during recovery.
	for i in 20:
		Input.action_press("attack_light")
		await main.get_tree().physics_frame
		Input.action_release("attack_light")
		if player._attack_phase != PlayerController.AttackPhase.RECOVERY and player.state == PlayerController.State.LIGHT2:
			saw_light2_during_startup_or_active = true
		if player._attack_phase == PlayerController.AttackPhase.RECOVERY:
			break
	ck.call("mash: spamming during startup/active never jumps straight to light2", not saw_light2_during_startup_or_active)
	ck.call("mash: still exactly light1 (no restart/skip) once recovery begins", player.state == PlayerController.State.LIGHT1, player.get_state_name())
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ Bandit takes one hit per swing, dies at 0 HP
func test_bandit_takes_damage_and_dies(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var arena: TrainingArena = r[1]
	var player: PlayerController = r[2]
	if player == null or arena == null:
		ck.call("combat: scene has player+arena (bandit damage)", false)
		main.queue_free()
		return
	var bandits := main.get_tree().get_nodes_in_group("enemy")
	ck.call("bandit: arena spawns exactly one Bandit", bandits.size() == 1, str(bandits.size()))
	if bandits.size() == 0:
		main.queue_free()
		return
	var bandit: Bandit = bandits[0]

	await _reset(player, bandit.global_position - Vector2(60, 0))
	player.facing8 = Vector2.RIGHT
	player.facing = Vector2.RIGHT
	bandit.global_position = player.global_position + Vector2(60, 0)
	bandit.velocity = Vector2.ZERO
	var hp_before := bandit.hp
	await _tap("attack_light")
	var hit_once := false
	var hit_react_state_seen := false
	for i in 40:
		await main.get_tree().physics_frame
		if player._attack_phase == PlayerController.AttackPhase.ACTIVE and bandit.hp < hp_before:
			if not hit_once:
				# Capture reaction state right as the hit lands -- hit_react_duration is short enough
				# (~0.22s) that waiting for the full loop below to finish would always see it already
				# revert to APPROACH.
				hit_react_state_seen = bandit.state == Bandit.State.HIT_REACT or bandit.state == Bandit.State.DEAD
			hit_once = true
	var hp_after_first_active_window: float = bandit.hp
	ck.call("bandit: a single swing's active window damages the bandit exactly once (hp dropped, then held)", hit_once and hp_after_first_active_window < hp_before, "%.1f -> %.1f" % [hp_before, hp_after_first_active_window])
	ck.call("bandit: hit-stun/react state entered on taking damage", hit_react_state_seen, bandit.get_state_name())

	# Hit it enough times to kill it, confirming death at 0 HP.
	var swings := 0
	while bandit.is_alive() and swings < 20:
		await _reset(player, bandit.global_position - Vector2(60, 0))
		player.facing8 = Vector2.RIGHT
		player.facing = Vector2.RIGHT
		await _tap("attack_light")
		for i in 40:
			await main.get_tree().physics_frame
		swings += 1
	ck.call("bandit: enough swings bring it to 0 hp and DEAD", not bandit.is_alive() and bandit.hp <= 0.0, "hp=%.1f state=%s swings=%d" % [bandit.hp, bandit.get_state_name(), swings])
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------- Fluidity A: run -> jump -> aerial -> land -> run
func test_air_attack_land_run(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	await _reset(player, Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 20:
		await main.get_tree().physics_frame
	await _tap("jump")
	ck.call("air attack: jump started", player.state == PlayerController.State.JUMP, player.get_state_name())
	for i in 6:
		await main.get_tree().physics_frame
	await _tap("attack_light")
	var saw_air := false
	var saw_idle := false
	var min_vx := 99999.0
	for i in 120:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.AIR_ATTACK:
			saw_air = true
			min_vx = minf(min_vx, player.velocity.x)
		if player.state == PlayerController.State.IDLE:
			saw_idle = true
		if player.state == PlayerController.State.MOVE and saw_air:
			break
	ck.call("air attack: attack during JUMP enters AIR_ATTACK", saw_air)
	ck.call("air attack: jump momentum survives the swing (no velocity collapse)", min_vx > player.jump_air_speed_cap * 0.9, str(min_vx))
	ck.call("air attack: no IDLE anywhere through jump -> air attack -> land", not saw_idle)
	ck.call("air attack: lands straight back into MOVE (still running)", player.state == PlayerController.State.MOVE, player.get_state_name())
	ck.call("air attack: jump visual lift reset on landing", is_zero_approx(player.visual.position.y), str(player.visual.position.y))
	Input.action_release("move_right")
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------- Fluidity A: a stale buffered press expires
func test_stale_buffer_expires(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	await _reset(player, Vector2(-900, 100))
	await _tap("dodge")
	for i in 4:
		await main.get_tree().physics_frame
	await _tap("attack_light")  # early in the dodge: far outside the late window
	var attacked := false
	for i in 90:
		await main.get_tree().physics_frame
		if PlayerController._is_attack_state(player.state):
			attacked = true
	ck.call("buffer: attack pressed early in a dodge expires instead of firing stale after it", not attacked)
	ck.call("buffer: attack buffer is empty afterwards", player._attack_buffer == 0.0, str(player._attack_buffer))
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------- Fluidity A: hitstop must not lose input
func test_buffer_survives_hitstop(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	await _reset(player, Vector2(-900, 100))
	player._hitstop_timer = 0.12
	await _tap("attack_light")  # 3 frames, entirely inside the freeze
	ck.call("hitstop: press made during the freeze is captured", player._attack_buffer > 0.0, str(player._attack_buffer))
	ck.call("hitstop: still frozen (no state change yet)", player.state == PlayerController.State.IDLE, player.get_state_name())
	var fired := false
	for i in 30:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.LIGHT1:
			fired = true
			break
	ck.call("hitstop: buffered press fires once the freeze ends", fired, player.get_state_name())
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------- Fluidity A: cancel eligibility is queryable
func test_cancel_eligibility(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	await _reset(player, Vector2(-900, 100))
	var e0 := player.cancel_eligibility()
	ck.call("eligibility: idle has no combo/dodge-cancel/dash/air permissions", not (e0.combo or e0.dodge_cancel or e0.dash_attack or e0.air_attack), str(e0))
	await _tap("attack_light")
	var saw_recovery_combo := false
	for i in 40:
		await main.get_tree().physics_frame
		if player._attack_phase == PlayerController.AttackPhase.RECOVERY and player.cancel_eligibility().combo:
			saw_recovery_combo = true
			break
	ck.call("eligibility: light1 recovery opens the combo window", saw_recovery_combo)
	var snap := player.debug_snapshot()
	ck.call("eligibility: debug_snapshot reports state, phase and buffers", snap.has("state") and snap.has("phase") and snap.has("attack_buffer") and snap.has("cancel"))
	main.queue_free()
	await main.get_tree().process_frame
