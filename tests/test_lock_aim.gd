extends RefCounted
## With R3 locked on, throws, swings and Chidori aim at the target (any angle); without a lock they use the facing.

var ck: Callable


func _dummy(root: Node, pos: Vector2) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nfunc take_damage(_a, _d = Vector2.ZERO, _k = 0.0, _h = 0.0):\n\tpass\nfunc is_alive():\n\treturn true\n"
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.add_to_group("enemy")
	root.add_child(n)
	n.global_position = pos
	return n


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	Bandit.substitution_enabled = false
	AncientShrineSection.enabled = false
	MapEditorMode.forced = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena")
	var player := arena.get_node("Player") as PlayerController
	var bandit := arena.get_node_or_null("Bandit")
	if bandit != null:
		bandit.queue_free()
	await tree.process_frame
	var lock := player.get_node("LockOn") as PlayerLockOn

	player.facing8 = Vector2.RIGHT
	ck.call("lock-aim: no lock falls back to the facing", player.aim_direction().is_equal_approx(Vector2.RIGHT) and player.lock_aim_dir() == Vector2.ZERO)

	var foe := _dummy(arena, player.global_position + Vector2(300, 120))
	var want := (foe.global_position - player.global_position).normalized()
	lock.toggle()
	ck.call("lock-aim: locked on the foe", lock.target == foe)
	ck.call("lock-aim: aim points straight at the target, not an 8-way snap", player.aim_direction().is_equal_approx(want) and not want.is_equal_approx(Vector2.RIGHT))

	player.inventory.add("kunai", 3)
	player.state = PlayerController.State.IDLE
	var threw := player._begin_throw("kunai")
	ck.call("lock-aim: a throw is started", threw)
	if threw:
		ck.call("lock-aim: the thrown kunai is aimed at the target", player._throw_dir.is_equal_approx(want))
		ck.call("lock-aim: the thrower faces the target", player.facing8.dot(want) > 0.9)

	player.state = PlayerController.State.IDLE
	player._throw_t = 0.0
	player.facing8 = Vector2.UP
	player._begin_attack("light1")
	ck.call("lock-aim: a swing turns to the target even if you were facing away", player.facing8.dot(want) > 0.9)

	player._cancel_chidori()
	player.state = PlayerController.State.IDLE
	player.chakra = 100.0
	player.chidori_cd = 0.0
	player.facing8 = Vector2.UP
	var started := player._begin_chidori()
	ck.call("lock-aim: chidori starts", started)
	if started:
		ck.call("lock-aim: chidori is aimed at the target", player.chidori_dir.is_equal_approx(want))

	lock.toggle()
	ck.call("lock-aim: unlocking returns aim to the facing", player.lock_aim_dir() == Vector2.ZERO)
	main.queue_free()
	await tree.process_frame
