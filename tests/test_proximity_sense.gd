extends RefCounted
## Proximity "power level" sense (ProximitySense) -- pure math, and the player/bandit hook-up.
## Owner: "when naruto running and near enemy ... player will auto detect and pull their kunai out";
## "the higher the stat the bigger the circle". Player: SPRINT-gated, see PlayerController.sense_radius/
## kunai_drawn/sensed_enemy. Bandit: is_sprinting-gated, see Bandit.sense_radius/senses_player.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_radius_formula()
	test_radius_clamps()
	await test_nearest_in_radius(tree_root)
	await test_bandit_proximity_sense(tree_root)
	await test_player_proximity_sense(tree_root)


# ------------------------------------------------------------------ pure math
func test_radius_formula() -> void:
	var r0 := ProximitySense.radius_for(0)
	var r5 := ProximitySense.radius_for(5)
	var r20 := ProximitySense.radius_for(20)
	ck.call("ProximitySense: radius grows monotonically with intelligence (0 < 5 < 20)", r0 < r5 and r5 < r20, "%s %s %s" % [r0, r5, r20])
	ck.call("ProximitySense: radius_for(0) equals BASE_RADIUS", is_equal_approx(r0, ProximitySense.BASE_RADIUS), str(r0))
	ck.call("ProximitySense: radius_for(5) is BASE + 5 x RADIUS_PER_POINT", is_equal_approx(r5, ProximitySense.BASE_RADIUS + 5.0 * ProximitySense.RADIUS_PER_POINT), str(r5))


func test_radius_clamps() -> void:
	var neg := ProximitySense.radius_for(-50)
	var huge := ProximitySense.radius_for(100000)
	ck.call("ProximitySense: negative intelligence clamps to BASE_RADIUS, not zero/negative", is_equal_approx(neg, ProximitySense.BASE_RADIUS), str(neg))
	ck.call("ProximitySense: absurdly large intelligence clamps at MAX_RADIUS", is_equal_approx(huge, ProximitySense.MAX_RADIUS), str(huge))


# ------------------------------------------------------------------ nearest_in_radius (group scan)
func test_nearest_in_radius(tree_root: Node) -> void:
	var origin := Vector2(5000, 5000)  ## far from anything else alive in the suite's shared tree
	var near := Node2D.new()
	near.global_position = origin + Vector2(100, 0)
	near.add_to_group("sense_test_targets")
	tree_root.add_child(near)
	var mid := Node2D.new()
	mid.global_position = origin + Vector2(300, 0)
	mid.add_to_group("sense_test_targets")
	tree_root.add_child(mid)
	var outside := Node2D.new()
	outside.global_position = origin + Vector2(900, 0)
	outside.add_to_group("sense_test_targets")
	tree_root.add_child(outside)
	await tree_root.get_tree().process_frame

	var found := ProximitySense.nearest_in_radius(origin, 400.0, "sense_test_targets", tree_root.get_tree())
	ck.call("ProximitySense.nearest_in_radius: picks the closest in-range member, not the farther one", found == near, str(found))
	var found_excl := ProximitySense.nearest_in_radius(origin, 400.0, "sense_test_targets", tree_root.get_tree(), near)
	ck.call("ProximitySense.nearest_in_radius: excludes the given node (falls through to the next-nearest)", found_excl == mid, str(found_excl))
	var found_far := ProximitySense.nearest_in_radius(origin, 400.0, "sense_test_targets", tree_root.get_tree())
	ck.call("ProximitySense.nearest_in_radius: a member beyond radius is never returned", found_far != outside)
	var found_none := ProximitySense.nearest_in_radius(origin, 50.0, "sense_test_targets", tree_root.get_tree())
	ck.call("ProximitySense.nearest_in_radius: returns null when nothing is in range", found_none == null, str(found_none))

	near.queue_free()
	mid.queue_free()
	outside.queue_free()
	await tree_root.get_tree().process_frame


# ------------------------------------------------------------------ Bandit integration
func test_bandit_proximity_sense(tree_root: Node) -> void:
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	tree_root.add_child(player)
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	tree_root.add_child(bandit)
	bandit.set_physics_process(false)
	bandit._player = player
	bandit.intelligence = 5
	bandit.position = Vector2(8000, 8000)  ## far from the real training-arena bandit/world geometry

	ck.call("Bandit.sense_radius: matches ProximitySense.radius_for(intelligence)", is_equal_approx(bandit.sense_radius(), ProximitySense.radius_for(5)), str(bandit.sense_radius()))

	# Player due EAST of the bandit, bandit facing NORTH (90 deg off, well outside its 110 deg FOV) and
	# beyond `close_sense` (150px): the existing cone-based sight is structurally excluded at this offset,
	# so a state change can only come from the new proximity sense, not the unrelated vision mechanic.
	var offset := Vector2(200, 0)  ## outside close_sense(150), inside sense_radius(300 @ intelligence=5)
	player.global_position = bandit.global_position + offset

	# Not naruto-running: even a player standing this close is not auto-noticed via the sense circle.
	bandit.facing8 = Vector2.UP
	bandit.is_sprinting = false
	bandit.state = Bandit.State.PATROL
	bandit._physics_process(1.0 / 60.0)
	ck.call("Bandit sense: not naruto-running -> no proximity auto-detect even when close", not bandit.senses_player and bandit.state == Bandit.State.PATROL, "senses=%s state=%s" % [bandit.senses_player, bandit.get_state_name()])

	# Naruto-running (is_sprinting) and within the circle while PATROL -> auto-detect -> NOTICE.
	bandit.facing8 = Vector2.UP
	bandit.is_sprinting = true
	bandit.state = Bandit.State.PATROL
	bandit._physics_process(1.0 / 60.0)
	ck.call("Bandit sense: naruto-running + in-radius + PATROL -> senses_player and enters NOTICE", bandit.senses_player and bandit.state == Bandit.State.NOTICE, "senses=%s state=%s" % [bandit.senses_player, bandit.get_state_name()])

	# Too far away even while sprinting -> no detection (still facing away from the player, same offset axis).
	player.global_position = bandit.global_position + offset.normalized() * (bandit.sense_radius() + 50.0)
	bandit.facing8 = Vector2.UP
	bandit.is_sprinting = true
	bandit.state = Bandit.State.PATROL
	bandit._physics_process(1.0 / 60.0)
	ck.call("Bandit sense: naruto-running but beyond sense_radius -> no auto-detect", not bandit.senses_player and bandit.state == Bandit.State.PATROL, "senses=%s state=%s dist=%s radius=%s" % [bandit.senses_player, bandit.get_state_name(), player.global_position.distance_to(bandit.global_position), bandit.sense_radius()])

	player.queue_free()
	bandit.queue_free()
	await tree_root.get_tree().process_frame


# ------------------------------------------------------------------ PlayerController integration
func test_player_proximity_sense(tree_root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	var tree := p.get_tree()
	var home := Vector2(-400, 135)  ## far from WorldScale.BANDIT_HOME (1300,-130): no interference
	p.intelligence = 5
	ck.call("PlayerController.sense_radius: matches ProximitySense.radius_for(intelligence)", is_equal_approx(p.sense_radius(), ProximitySense.radius_for(5)), str(p.sense_radius()))

	var dummy := Node2D.new()
	dummy.add_to_group("enemy")
	tree_root.add_child(dummy)

	# Each phase below re-teleports the player to a fixed spot and re-zeroes velocity first, so a few
	# frames of real SPRINT_SPEED motion (~600 px/s) between checks cannot drift the measured distance.
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)

	# Walking (not sprinting) near the dummy: no auto-detect, no kunai_drawn, even though it is in range.
	p.state = PlayerController.State.IDLE
	p.velocity = Vector2.ZERO
	p.global_position = home
	dummy.global_position = home + Vector2(150, 0)  ## inside the 300px radius at intelligence=5
	Input.action_press("move_right")
	for i in 3:
		await tree.physics_frame
	ck.call("Player sense: walking (not sprinting) near an enemy -> no kunai_drawn", not p.kunai_drawn and p.sensed_enemy == null, "state=%s drawn=%s" % [p.get_state_name(), p.kunai_drawn])
	Input.action_release("move_right")

	# Sprinting (naruto running) near the dummy: auto-detect + kunai_drawn.
	p.state = PlayerController.State.IDLE
	p.velocity = Vector2.ZERO
	p.global_position = home
	dummy.global_position = home + Vector2(150, 0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 3:
		await tree.physics_frame
	ck.call("Player sense: sprinting (naruto running) near an enemy -> auto-detects it", p.state == PlayerController.State.SPRINT and p.sensed_enemy == dummy and p.kunai_drawn, "state=%s sensed=%s drawn=%s" % [p.get_state_name(), p.sensed_enemy, p.kunai_drawn])
	Input.action_release("move_right")
	Input.action_release("sprint")

	# Sprinting but the enemy is well beyond sense_radius -> clears (large buffer, position re-pinned).
	p.state = PlayerController.State.IDLE
	p.velocity = Vector2.ZERO
	p.global_position = home
	dummy.global_position = home + Vector2(p.sense_radius() + 400.0, 0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 3:
		await tree.physics_frame
	ck.call("Player sense: sprinting but the enemy is beyond sense_radius -> no detection", p.state == PlayerController.State.SPRINT and p.sensed_enemy == null and not p.kunai_drawn, "sensed=%s drawn=%s" % [p.sensed_enemy, p.kunai_drawn])
	Input.action_release("move_right")
	Input.action_release("sprint")

	# Releasing sprint clears kunai_drawn/sensed_enemy on the very next frame, even with the enemy in range.
	p.state = PlayerController.State.IDLE
	p.velocity = Vector2.ZERO
	p.global_position = home
	dummy.global_position = home + Vector2(150, 0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 3:
		await tree.physics_frame
	Input.action_release("sprint")
	for i in 3:
		await tree.physics_frame
	ck.call("Player sense: releasing sprint clears kunai_drawn/sensed_enemy", not p.kunai_drawn and p.sensed_enemy == null, "state=%s drawn=%s" % [p.get_state_name(), p.kunai_drawn])

	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)
	dummy.queue_free()
	main.queue_free()
	await tree_root.get_tree().process_frame
