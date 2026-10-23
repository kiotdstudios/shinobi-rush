extends RefCounted

func run(ck: Callable, tree_root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	for enemy in main.get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	# Exercise the existing L2 action without changing its press/substitution code.
	Input.action_press("substitution")
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: initial L2 press retains substitution window and does not charge", p._sub_buffer > 0.0 and p.state != PlayerController.State.CHARGE)
	Input.action_release("substitution")
	for i in 3:
		await main.get_tree().physics_frame
	Input.action_press("substitution")
	for i in 24:
		await main.get_tree().physics_frame
	ck.call("charge: sustained existing L2 action charges after hold delay", p.state == PlayerController.State.CHARGE)
	Input.action_release("substitution")
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: releasing L2 stops charge", p.state == PlayerController.State.IDLE)
	p.chakra = 30.0
	var start := p.global_position
	Input.action_press("chakra_charge")
	Input.action_press("move_right")
	for i in 12:
		await main.get_tree().physics_frame
	ck.call("charge: hold enters planted charge", p.state == PlayerController.State.CHARGE and p.global_position.is_equal_approx(start))
	ck.call("charge: chakra increases and body has no weapon overlay", p.chakra > 30.0 and p.visual.last_anim == "charge" and not p.visual.weapon_visible())
	for direction in SpriteSet.DIRS8:
		for set_path in ["res://assets/characters/player/player_128.manifest.json", "res://assets/characters/bandit/bandit_128.art.json"]:
			var s := SpriteSet.parse(FileAccess.get_file_as_string(set_path), set_path)
			var frames := s.get_frames("charge")
			ck.call("charge art: " + set_path + " " + direction, s.is_valid() and frames.get_frame_count(direction) == 16 and frames.get_animation_loop(direction) and is_equal_approx(frames.get_animation_speed(direction), 6.0))
	p.chakra = 99.9
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: recovery caps at maximum", is_equal_approx(p.chakra, p.max_chakra))
	Input.action_release("chakra_charge")
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: release resumes held movement", p.state == PlayerController.State.MOVE and p.global_position.x > start.x)
	Input.action_release("move_right")
	Input.action_press("chakra_charge")
	for i in 3:
		await main.get_tree().physics_frame
	Input.action_press("dodge")
	for i in 2:
		await main.get_tree().physics_frame
	ck.call("charge: dodge interrupts charge", p.state == PlayerController.State.DODGE)
	Input.action_release("dodge")
	Input.action_release("chakra_charge")
	for i in 30:
		await main.get_tree().physics_frame
	Input.action_press("chakra_charge")
	for i in 3:
		await main.get_tree().physics_frame
	p._hit_invuln = 0.0
	p.take_hit(1.0, Vector2.LEFT, 0.0)
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: damage interrupts until release", p.state != PlayerController.State.CHARGE and p._charge_interrupted)
	Input.action_release("chakra_charge")
	await main.get_tree().physics_frame
	Input.action_press("chakra_charge")
	for i in 3:
		await main.get_tree().physics_frame
	ck.call("charge: fresh hold after damage can charge", p.state == PlayerController.State.CHARGE)
	Input.action_release("chakra_charge")
	main.queue_free()
	await tree_root.get_tree().process_frame
