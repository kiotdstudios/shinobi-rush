extends RefCounted
## Bandit substitution jutsu + three-kunai combo (Level 1 profile tunables).

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	Bandit.substitution_enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await root.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	var b := root.get_tree().get_first_node_in_group("enemy") as Bandit
	ck.call("bandit sub: actors exist", p != null and b != null)
	if p == null or b == null:
		Bandit.substitution_enabled = false
		main.queue_free()
		return
	p.set_physics_process(false)
	b.set_physics_process(false)
	var prof := EnemyIntelligence.profile(1)
	ck.call("bandit sub: profile exposes burst + sub tunables", int(prof.throw_burst_count) == 3 and float(prof.sub_chance) > 0.0 and float(prof.sub_recharge) > 0.0 and float(prof.sub_chakra_cost) > 0.0)

	# --- three-kunai combo
	b._player = p
	b.sees_player = true
	b._throw_cooldown = 0.0
	b._atk_cooldown = 0.0
	var arena := b.get_parent()
	var before_nodes := _kunai_count(arena)
	var before: int = b.kunai_thrown
	b._begin_throw()
	var t := 0.0
	while b.atk_phase != Bandit.AtkPhase.NONE and t < 4.0:
		b._tick_throw(0.02)
		t += 0.02
	ck.call("bandit kunai: one throw action releases three kunai", b.kunai_thrown == before + 3)
	ck.call("bandit kunai: three kunai are in flight", _kunai_count(arena) == before_nodes + 3)
	var angles := []
	for c in arena.get_children():
		if c is BanditKunai:
			angles.append(snappedf(rad_to_deg((c as BanditKunai).dir.angle()), 0.1))
	angles.sort()
	ck.call("bandit kunai: the three are fanned out (distinct angles)", angles.size() >= 3 and angles[angles.size() - 1] > angles[angles.size() - 3])
	for c in arena.get_children():
		if c is BanditKunai:
			c.queue_free()

	# --- substitution
	b.profile["sub_chance"] = 1.0
	b.state = Bandit.State.APPROACH
	b.hp = b.max_hp
	b.chakra = b.max_chakra
	b.substitutions = 2
	b._sub_gap = 0.0
	b._sub_invuln = 0.0
	p.global_position = b.global_position + Vector2(-90, 0)
	var old := b.global_position
	b.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	ck.call("bandit sub: a hit is swallowed (no damage)", is_equal_approx(b.hp, b.max_hp))
	ck.call("bandit sub: spends a charge and chakra", b.substitutions == 1 and b.chakra < b.max_chakra and b.substitution_count == 1)
	ck.call("bandit sub: he reappears behind the player", b.global_position.distance_to(old) > 40.0 and (b.global_position - p.global_position).dot(old - p.global_position) < 0.0)
	ck.call("bandit sub: grace window blocks an immediate second hit", _hit_ignored(b))
	b._sub_invuln = 0.0
	ck.call("bandit sub: the min-gap lockout stops back-to-back swaps", not b.can_substitute())
	b._sub_gap = 0.0
	b.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	ck.call("bandit sub: second charge is usable", b.substitutions == 0 and is_equal_approx(b.hp, b.max_hp))
	b._sub_gap = 0.0
	b._sub_invuln = 0.0
	b.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	ck.call("bandit sub: out of charges, the hit lands", is_equal_approx(b.hp, b.max_hp - 10.0))
	b._tick_substitution(float(b.profile.sub_recharge) + 0.1)
	ck.call("bandit sub: charges recharge over time", b.substitutions == 2)
	b.substitutions = 2
	b.chakra = 0.0
	b._sub_gap = 0.0
	b._sub_invuln = 0.0
	ck.call("bandit sub: no chakra means no swap", not b.can_substitute())
	b.chakra = b.max_chakra
	b.profile["sub_chance"] = 0.0
	b.hp = b.max_hp
	b.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	ck.call("bandit sub: zero chance never swaps", is_equal_approx(b.hp, b.max_hp - 10.0) and b.substitutions == 2)
	Bandit.substitution_enabled = false
	main.queue_free()
	await root.get_tree().process_frame


func _kunai_count(arena: Node) -> int:
	var n := 0
	for c in arena.get_children():
		if c is BanditKunai:
			n += 1
	return n


func _hit_ignored(b: Bandit) -> bool:
	var hp: float = b.hp
	b.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	return is_equal_approx(b.hp, hp)
