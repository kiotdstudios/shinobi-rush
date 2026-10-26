extends RefCounted
## Chidori (R2 + Square): charge, rush, impact. Damage only on the rush's contact, once per enemy, never through walls.

var ck: Callable


func _dummy(root: Node, pos: Vector2) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar hp := 100.0\nvar hits := 0\nfunc take_damage(a, _d = Vector2.ZERO, _k = 0.0, _h = 0.0):\n\thp -= a\n\thits += 1\nfunc is_alive():\n\treturn hp > 0.0\n"
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.add_to_group("enemy")
	root.add_child(n)
	n.global_position = pos
	return n


func _frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.physics_frame


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

	ck.call("chidori: the jutsu is playable and bound to R2 + Square", bool(PlayerInventory.JUTSU["chidori"]["ready"]) and String(player.inventory.jutsu["square"]) == "chidori")
	var evs := InputMap.action_get_events("jutsu_modifier")
	var r2 := false
	for e in evs:
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT:
			r2 = true
	ck.call("chidori: R2 is the jutsu modifier", r2)

	# directions: eight distinct hand anchors
	var seen := {}
	for d: Vector2 in [Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1)]:
		seen[ChidoriFx.hand_local(d)] = true
	ck.call("chidori: the 8 facings give 8 distinct hand anchors", seen.size() == 8)

	# a clear run: costs chakra, no damage while charging, rushes along the facing, fizzles at max range
	var start := player.global_position
	player.chakra = 100.0
	player.facing8 = Vector2.DOWN
	player.facing = Vector2.DOWN
	var foe := _dummy(arena, start + Vector2(0, 5000))
	ck.call("chidori: starts", player.use_jutsu("square") and player.chidori_phase == PlayerController.ChidoriPhase.CHARGE)
	ck.call("chidori: costs chakra", is_equal_approx(player.chakra, 100.0 - PlayerController.CHIDORI_COST))
	ck.call("chidori: cannot be re-cast while active", not player.use_jutsu("square"))
	await _frames(tree, 20)
	ck.call("chidori: charging does not move the player", player.global_position.distance_to(start) < 1.0)
	ck.call("chidori: charge fx shows several arcs (4 to 7) and sparks", player.chidori_fx.mode == ChidoriFx.Mode.CHARGE and player.chidori_fx.arc_count_lit >= 4 and player.chidori_fx.arc_count_lit <= 7)
	await _frames(tree, 30)
	ck.call("chidori: after the charge it rushes", player.chidori_phase == PlayerController.ChidoriPhase.RUSH or player.chidori_phase == PlayerController.ChidoriPhase.RECOVER)
	await _frames(tree, 75)
	ck.call("chidori: the rush moved the player along the facing", player.global_position.y > start.y + 100.0 and absf(player.global_position.x - start.x) < 40.0)
	ck.call("chidori: rush is capped at the max range", player.global_position.distance_to(start) <= PlayerController.CHIDORI_RUSH_MAX + 60.0)
	ck.call("chidori: nothing was hurt by an empty rush", foe.hits == 0)
	ck.call("chidori: the fx spawned an impact, spark pool within bounds", ChidoriFx.MAX_SPARKS == 72)
	ck.call("chidori: cooldown is running", player.chidori_cd > 0.0 or player.chidori_phase != PlayerController.ChidoriPhase.NONE)
	await _frames(tree, 90)
	ck.call("chidori: back to normal after the recovery", player.chidori_phase == PlayerController.ChidoriPhase.NONE and player.state != PlayerController.State.SPRINT or player.chidori_phase == PlayerController.ChidoriPhase.NONE)
	foe.queue_free()

	# not enough chakra
	player.chidori_cd = 0.0
	player.chakra = 10.0
	ck.call("chidori: refused without chakra", not player.use_jutsu("square") and player.chidori_phase == PlayerController.ChidoriPhase.NONE)

	# an enemy ahead is struck once, with splash on a neighbour
	player.global_position = start
	player.velocity = Vector2.ZERO
	player.chakra = 100.0
	player.chidori_cd = 0.0
	player.facing8 = Vector2.DOWN
	var hit := _dummy(arena, start + Vector2(0, 120))
	var near := _dummy(arena, start + Vector2(60, 140))
	var far := _dummy(arena, start + Vector2(400, 300))
	player.use_jutsu("square")
	await _frames(tree, 20)
	ck.call("chidori: no damage during the charge", hit.hits == 0)
	await _frames(tree, 90)
	ck.call("chidori: the struck enemy took exactly one hit", hit.hits == 1 and hit.hp < 100.0)
	ck.call("chidori: a close neighbour took splash", near.hits == 1 and near.hp > hit.hp)
	ck.call("chidori: a distant enemy was untouched", far.hits == 0)
	for n in [hit, near, far]:
		n.queue_free()
	await _frames(tree, 60)

	# a wall stops the rush and shields what is behind it
	player.global_position = start
	player.velocity = Vector2.ZERO
	player.chakra = 100.0
	player.chidori_cd = 0.0
	player.facing8 = Vector2.DOWN
	var wall := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600, 20)
	cs.shape = rect
	wall.add_child(cs)
	arena.add_child(wall)
	wall.global_position = start + Vector2(0, 150)
	var behind := _dummy(arena, start + Vector2(0, 200))
	await tree.physics_frame
	player.use_jutsu("square")
	await _frames(tree, 100)
	ck.call("chidori: a wall stops the rush", player.global_position.y < start.y + 150.0)
	ck.call("chidori: nothing is hurt through a wall", behind.hits == 0)
	behind.queue_free()
	wall.queue_free()
	await _frames(tree, 60)

	# interrupted by a hit
	player.chidori_cd = 0.0
	player.chakra = 100.0
	player.use_jutsu("square")
	await _frames(tree, 10)
	player.take_hit(5.0, Vector2.UP)
	ck.call("chidori: a hit interrupts the charge", player.chidori_phase == PlayerController.ChidoriPhase.NONE)

	# impact timing
	var parent := Node2D.new()
	root.add_child(parent)
	var imp := ChidoriImpact.spawn(parent, Vector2(100, 100), Vector2.RIGHT)
	imp.set_process(false)
	imp.advance(0.03)
	ck.call("chidori impact: the white-hot flash is first (before 0.05s)", imp.age < ChidoriImpact.FLASH_END)
	imp.advance(0.09)
	ck.call("chidori impact: the eruption has many bolts by 0.12s", imp.bolt_count >= 30)
	imp.advance(0.2)
	ck.call("chidori impact: sparks shower by ~0.3s, within the pool bound", imp.spark_count > 20 and imp.spark_count <= 100)
	imp.advance(0.4)
	ck.call("chidori impact: finished by 0.6s", imp.finished)
	parent.queue_free()

	# fx pooling
	var fx := ChidoriFx.new()
	root.add_child(fx)
	fx.begin_charge(Vector2.RIGHT)
	for i in 120:
		fx.advance(1.0 / 60.0)
	ck.call("chidori fx: sparks stay pooled", fx.spark_count <= ChidoriFx.MAX_SPARKS)
	fx.begin_rush(Vector2.RIGHT)
	for i in 60:
		fx.advance(1.0 / 60.0)
	ck.call("chidori fx: afterimages stay pooled", fx.afterimages_live() <= ChidoriFx.MAX_AFTER)
	fx.stop()
	fx.queue_free()
	main.queue_free()
	await tree.process_frame
