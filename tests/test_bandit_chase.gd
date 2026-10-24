extends RefCounted

func run(ck: Callable, root: Node) -> void:
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)
	var lock := PlayerLockOn.new()
	lock.name = "LockOn"
	player.add_child(lock)
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	root.add_child(bandit)
	bandit.set_physics_process(false)
	bandit._player = player
	bandit.position = Vector2.ZERO
	player.position = Vector2(350, 0)
	# Acquisition (cone, LOS, notice delay) is covered by test_bandit_robber.gd; this file covers the
	# chase / spacing / evade mechanics that start once the bandit is already hunting.
	bandit.state = Bandit.State.APPROACH
	bandit._physics_process(1.0 / 60.0)
	ck.call("bandit chase: detects and sprints", bandit.state == Bandit.State.APPROACH and bandit.is_sprinting and is_equal_approx(bandit.velocity.length(), bandit.chase_speed))
	var visual := bandit.visual as BanditVisual
	visual._process(0)
	ck.call("bandit chase: uses authored sprint", visual.actor.anim_id == "sprint")
	visual.actor.sprite.set_frame_and_progress(5, 0.4)
	bandit.facing8 = Vector2.UP
	visual._process(0)
	ck.call("bandit chase: turn preserves frame and subframe", visual.actor.sprite.frame == 5 and is_equal_approx(visual.actor.sprite.frame_progress, 0.4))
	player.position = bandit.position + Vector2(175, 0)
	bandit._physics_process(1.0 / 60.0)
	visual._process(0)
	ck.call("bandit chase: near pursuit uses run", not bandit.is_sprinting and visual.actor.anim_id == "run")
	ck.call("bandit chase: gait phase survives run transition", visual.actor.sprite.frame == 5)
	player.position = bandit.position + Vector2(120, 0)
	bandit._physics_process(0.3)
	visual._process(0)
	ck.call("bandit chase: waits in kunai guard at spacing", visual.actor.anim_id == "kunai_guard" and visual.weapon_visible())
	player.position = bandit.position + Vector2(140, 0)
	bandit._physics_process(0.02)
	ck.call("bandit chase: spacing deadband prevents chatter", bandit.velocity == Vector2.ZERO)
	lock.toggle()
	ck.call("bandit lock: selects living nearest enemy", lock.is_targeted(bandit))
	bandit._physics_process(0.02)
	visual._process(0)
	ck.call("bandit evade: real lock triggers burst", bandit.state == Bandit.State.EVADE and bandit.evade_count == 1 and visual.streak.visible)
	ck.call("bandit evade: correct six-frame separate effect", visual.streak.sprite_frames.get_frame_count("default") == 6 and visual.actor.anim_id == "sprint")
	bandit._physics_process(0.25)
	bandit._physics_process(0.02)
	ck.call("bandit evade: cooldown prevents repeat spam", bandit.evade_count == 1 and bandit.state != Bandit.State.EVADE)
	lock.toggle()
	ck.call("bandit lock: second toggle releases", not lock.valid_target())
	player.position = bandit.position + Vector2(180, 0)
	player.velocity = Vector2(-200, 0)
	bandit._evade_cooldown = 0
	bandit._physics_process(0.02)
	ck.call("bandit evade: approaching without lock triggers", bandit.state == Bandit.State.EVADE and bandit.evade_count == 2)
	bandit.substitutions = 0  # no log swap: these hits must land
	bandit.take_damage(1, Vector2.LEFT, 20, 0)
	visual._process(0)
	ck.call("bandit evade: damage interrupts and hides streak", bandit.state == Bandit.State.HIT_REACT and not visual.streak.visible)
	lock.toggle()
	bandit.take_damage(1000, Vector2.ZERO, 0, 0)
	lock._process(0)
	ck.call("bandit lock: dead target clears", not lock.valid_target())
	bandit.state = Bandit.State.APPROACH
	var walls: Array[StaticBody2D] = []
	for offset: float in [-75.0, 75.0]:
		var wall := StaticBody2D.new()
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(800, 12)
		collider.shape = box
		wall.add_child(collider)
		wall.position = bandit.position + Vector2(0, offset)
		root.add_child(wall)
		walls.append(wall)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("bandit evade: refuses burst when both sides blocked", not bandit._begin_evade(Vector2.RIGHT * 150))
	for wall in walls:
		wall.queue_free()
	bandit.queue_free()
	player.queue_free()
	await root.get_tree().process_frame
