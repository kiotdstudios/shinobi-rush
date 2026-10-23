extends RefCounted
## Player health + health bar, and the Body Flicker dodge (visibility, wall stop, invulnerability, fx cleanup).

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	await test_health(p)
	await test_flicker(p, main.get_tree())
	main.queue_free()
	await tree_root.get_tree().process_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)


func test_health(p: PlayerController) -> void:
	var bar := p.get_node_or_null("HealthBar") as HealthBar
	ck.call("health: the player has a HealthBar child and starts at full health", bar != null and p.health == p.max_health and p.max_health == 100.0)
	ck.call("health: the bar starts full", bar != null and is_equal_approx(bar.fraction, 1.0) and bar.label_text == "HP 100 / 100", str(bar.label_text) if bar else "")
	p._hit_invuln = 0.0
	p.state = PlayerController.State.IDLE
	var landed := p.take_hit(8.0, Vector2.RIGHT)
	ck.call("health: a landed 8 damage hit lowers health to 92 and the bar follows", landed and p.health == 92.0 and is_equal_approx(bar.fraction, 0.92) and bar.label_text == "HP 92 / 100", "%s %s" % [p.health, bar.label_text])
	var again := p.take_hit(8.0, Vector2.RIGHT)
	ck.call("health: hit-invulnerability blocks a second hit (no extra damage)", not again and p.health == 92.0)
	p._hit_invuln = 0.0
	p.state = PlayerController.State.DODGE
	ck.call("health: an evading player takes no damage", not p.take_hit(8.0, Vector2.RIGHT) and p.health == 92.0)
	p.state = PlayerController.State.IDLE
	p.restore_health(500.0)
	ck.call("health: restore_health clamps at max", p.health == 100.0)
	p.health = 5.0
	p._hit_invuln = 0.0
	var downs := p.times_downed
	var respawns := p.respawn_count
	var spawn := p.spawn_position
	p.global_position = spawn + Vector2(300, 120)
	p.velocity = Vector2(200, 50)
	p.take_hit(8.0, Vector2.RIGHT)
	ck.call("health: reaching 0 counts a knock-down and restores the player to full", p.times_downed == downs + 1 and p.health == p.max_health)
	ck.call("respawn: a downed player is put back at the spawn point, at rest, in IDLE", p.respawn_count == respawns + 1 and p.global_position.is_equal_approx(spawn) and p.velocity == Vector2.ZERO and p.state == PlayerController.State.IDLE, str(p.global_position))
	ck.call("respawn: the player gets a grace period after respawning", p._hit_invuln > 1.0)
	ck.call("respawn: further hits during the grace period do not land", not p.take_hit(50.0, Vector2.LEFT) and p.health == p.max_health)
	p._hit_invuln = 0.0
	p.health = 20.0
	p.max_health = 100.0
	p.health_changed.emit(p.health, p.max_health)
	ck.call("health: the bar turns red at or below 30 percent", bar.fill_color() == HealthBar.COL_LOW)
	p.restore_health(100.0)
	ck.call("health: the bar is orange again when healthy", bar.fill_color() == HealthBar.COL_FILL)
	ck.call("hud: chakra starts full at 100 with 3 substitution charges", p.chakra == 100.0 and p.max_chakra == 100.0 and p.substitution_charges == 3 and p.max_substitution_charges == 3)
	ck.call("hud: chakra bar starts full", is_equal_approx(bar.chakra_fraction, 1.0) and bar.chakra_text == "Chakra 100 / 100", bar.chakra_text)
	p.chakra_changed.emit(64.0, 100.0)
	ck.call("hud: chakra_changed updates the chakra bar", is_equal_approx(bar.chakra_fraction, 0.64) and bar.chakra_text == "Chakra 64 / 100", bar.chakra_text)
	p.substitution_changed.emit(2, 3)
	ck.call("hud: substitution_changed updates the pips", bar.pips == 2 and bar.max_pips == 3, str(bar.pips))
	ck.call("hud: substitution recharge is 20 seconds", is_equal_approx(PlayerController.SUB_COOLDOWN, 20.0))
	ck.call("hud: nothing recharging reads as full progress", is_equal_approx(p.substitution_progress(), 1.0) and is_equal_approx(bar.sub_progress, 1.0))
	var keep: Array = p._sub_cooldowns.duplicate()
	p._sub_cooldowns.assign([15.0, 5.0])
	ck.call("hud: progress follows the soonest charge (5s left of 20 = 0.75)", is_equal_approx(p.substitution_progress(), 0.75), str(p.substitution_progress()))
	p._sub_cooldowns.assign(keep)
	var before_pips: int = bar.pips
	p.substitution_changed.emit(0, 3)
	p.substitution_changed.emit(1, 3)
	ck.call("hud: a refilled charge lights its pip (flash) and the slot reads recharging until all are back", bar.pips == 1 and bar._flash[0] > 0.0 and bar.pips < bar.max_pips)
	p.substitution_changed.emit(before_pips, 3)
	p.chakra_changed.emit(100.0, 100.0)
	p.substitution_changed.emit(3, 3)


func test_flicker(p: PlayerController, tree: SceneTree) -> void:
	_release_all()
	p.state = PlayerController.State.IDLE
	p.global_position = Vector2(-900, 100)
	p.velocity = Vector2.ZERO
	p._dodge_buffer = 0.0
	p._hit_invuln = 0.0
	for i in 5:
		await tree.physics_frame
	var start := p.global_position
	Input.action_press("move_right")
	Input.action_press("dodge")
	for i in 3:
		await tree.physics_frame
	Input.action_release("dodge")
	var was_hidden := false
	var invuln := true
	var frames := 0
	while p.state == PlayerController.State.DODGE and frames < 90:
		if not p.visual.visible:
			was_hidden = true
		invuln = invuln and not p.take_hit(8.0, Vector2.LEFT)
		await tree.physics_frame
		frames += 1
	ck.call("flicker: the body disappears during the dodge and is visible again when it ends", was_hidden and p.visual.visible, "hidden=%s visible=%s" % [was_hidden, p.visual.visible])
	ck.call("flicker: nothing lands during the whole dodge", invuln and p.health == p.max_health)
	ck.call("flicker: the body moved along the heading in one step (about flicker_distance)", p.global_position.x - start.x > p.flicker_distance * 0.9, str(p.global_position - start))
	Input.action_release("move_right")
	for i in 40:
		await tree.physics_frame
	var fx_left := 0
	for c in p.get_parent().get_children():
		if c is BodyFlickerFx:
			fx_left += 1
	ck.call("flicker: the effect node frees itself after it plays", fx_left == 0, str(fx_left))
	# a wall stops the displacement short
	_release_all()
	p.state = PlayerController.State.IDLE
	var b := WorldScale.ARENA_BOUNDS
	p.global_position = Vector2(b.end.x - 40.0, 100)
	p.velocity = Vector2.ZERO
	p._dodge_buffer = 0.0
	for i in 5:
		await tree.physics_frame
	var wall_start := p.global_position
	Input.action_press("move_right")
	Input.action_press("dodge")
	for i in 3:
		await tree.physics_frame
	Input.action_release("dodge")
	frames = 0
	while p.state == PlayerController.State.DODGE and frames < 90:
		await tree.physics_frame
		frames += 1
	Input.action_release("move_right")
	ck.call("flicker: a wall shortens the displacement and the body is visible afterwards", p.global_position.x - wall_start.x < p.flicker_distance * 0.6 and p.visual.visible and p.global_position.x <= b.end.x, str(p.global_position - wall_start))
	var o := BodyFlickerFx.orientation(Vector2(1, 1))
	var ow := BodyFlickerFx.orientation(Vector2(-1, 1))
	ck.call("flicker fx: SE art is unrotated; SW is its mirror", is_zero_approx(o["rotation"]) and not o["mirror"] and is_zero_approx(ow["rotation"]) and ow["mirror"])
