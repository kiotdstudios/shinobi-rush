extends RefCounted
## Substitution Jutsu (L2) + Bandit kunai throw: timing window, charges / per-charge cooldown, rear
## placement + fallback, single proc, dodge regression; kunai flight / evade; throw state machine; art.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	var arena := main.get_node("TrainingArena")
	await test_substitution(p, arena)
	await test_kunai(p, arena)
	await test_throw(p, arena)
	test_art()
	main.queue_free()
	await tree_root.get_tree().process_frame


func _reset(p: PlayerController) -> void:
	# Each scenario starts with a clean arena. Physical substitution logs now
	# block movement, so a previous scenario's still-live log must not affect
	# the next scenario's swap/teleport collision probe.
	var arena := p.get_parent()
	if arena != null:
		for child in arena.get_children():
			if child is SubstitutionFx:
				child.free()
	p.state = PlayerController.State.IDLE
	p._hit_invuln = 0.0
	p._sub_buffer = 0.0
	p._sub_cooldowns.clear()
	p.substitution_charges = p.max_substitution_charges
	p.visual.visible = true
	p._sub_reveal = 0.0


func _dummy(arena: Node, at: Vector2) -> Node2D:
	var n := Node2D.new()
	arena.add_child(n)
	n.global_position = at
	return n


func test_substitution(p: PlayerController, arena: Node) -> void:
	_reset(p)
	var start := p.global_position
	var att := _dummy(arena, start + Vector2(100, 0))
	var hits := p.hits_taken
	var hp := p.health
	p._sub_buffer = PlayerController.SUB_WINDOW
	var landed := p.take_hit(8.0, Vector2.RIGHT, 180.0, att)
	var moved := p.global_position.distance_to(start) > 1.0
	var behind := (p.global_position - att.global_position).x >= -0.5
	ck.call("sub: a timed L2 press swallows the hit (no damage, hits_taken unchanged)", not landed and p.hits_taken == hits and p.health == hp)
	ck.call("sub: success consumes exactly one charge and emits the new count", p.substitution_charges == 2 and p._sub_cooldowns.size() == 1 and p.substitution_count == 1)
	ck.call("sub: the player reappears on the far side of the attacker (or stays put when blocked)", moved and behind or not moved, str(p.global_position))
	var b: Rect2 = arena.get_bounds()
	ck.call("sub: reappearance stays inside the arena bounds", b.has_point(p.global_position))
	ck.call("sub: i-frames follow a swap so a simultaneous second hit cannot land", p._hit_invuln > 0.0 and not p.take_hit(8.0, Vector2.RIGHT, 180.0, att) and p.substitution_charges == 2)
	ck.call("sub: the body is concealed for the swap beat, then revealed", not p.visual.visible and p._sub_reveal > 0.0)
	p._tick_substitution(0.2)
	ck.call("sub: the body is revealed again after the swap beat", p.visual.visible)
	ck.call("sub: a swap spawns the effect node", arena.get_node_or_null("SubstitutionFx") != null or _has_child_named(arena, "SubstitutionFx"))
	var fxn := arena.get_node_or_null("SubstitutionFx") as SubstitutionFx
	if fxn != null:
		var foot := Vector2(1234, 567)
		var far := SubstitutionFx.spawn(arena, foot, foot + Vector2(80, 0))
		for i in 30:
			far._process(0.05)
			var ls: Sprite2D = far._log_sprite
			if ls != null and ls.visible:
				ck.call("sub: the log stays near its drop point (t=%.2f)" % far._age, ls.global_position.distance_to(foot) < 90.0, str(ls.global_position))
				if far._age > 0.6:
					break
		far.queue_free()
	p._tick_substitution(PlayerController.SUB_COOLDOWN + 0.1)
	ck.call("sub: the spent charge recharges on its own cooldown", p.substitution_charges == 3 and p._sub_cooldowns.is_empty())

	_reset(p)
	p.global_position = start
	var h2 := p.hits_taken
	ck.call("sub: no L2 press means the hit lands normally and spends no charge", p.take_hit(8.0, Vector2.RIGHT, 180.0, att) and p.hits_taken == h2 + 1 and p.substitution_charges == 3)

	_reset(p)
	p._sub_buffer = PlayerController.SUB_WINDOW
	p._tick_substitution(PlayerController.SUB_WINDOW + 0.05)
	ck.call("sub: an L2 press outside the window (too early) expires and does nothing", p.take_hit(8.0, Vector2.RIGHT, 180.0, att) and p.substitution_charges == 3)

	_reset(p)
	p._sub_cooldowns.assign([5.0, 5.0, 5.0])
	p.substitution_charges = 0
	p._sub_buffer = PlayerController.SUB_WINDOW
	ck.call("sub: with no charges left a timed L2 does not save the player", p.take_hit(8.0, Vector2.RIGHT, 180.0, att))

	_reset(p)
	p._sub_cooldowns.assign([10.0])
	p.substitution_charges = 2
	p._sub_buffer = PlayerController.SUB_WINDOW
	var s := p.take_hit(8.0, Vector2.RIGHT, 180.0, att)
	ck.call("sub: charges keep independent cooldowns (another charge still usable)", not s and p.substitution_charges == 1 and p._sub_cooldowns.size() == 2)
	p._tick_substitution(10.5)
	ck.call("sub: the older charge returns first while the newer one is still cooling", p.substitution_charges == 2 and p._sub_cooldowns.size() == 1)

	_reset(p)
	p.global_position = start
	var hp3 := p.health
	p.state = PlayerController.State.DODGE
	p._sub_buffer = PlayerController.SUB_WINDOW
	ck.call("sub: a real dodge still evades and spends no charge", not p.take_hit(8.0, Vector2.RIGHT, 180.0, att) and p.substitution_charges == 3 and p.health == hp3)
	p.state = PlayerController.State.IDLE

	_reset(p)
	p.global_position = start
	var stale := _dummy(arena, start + Vector2(90, 0))
	stale.queue_free()
	await arena.get_tree().process_frame
	p._sub_buffer = PlayerController.SUB_WINDOW
	var ok := not p.take_hit(8.0, Vector2.RIGHT, 180.0, stale)
	ck.call("sub: a freed attacker is handled (swap still saves the hit, player stays put)", ok and p.global_position.distance_to(start) < 0.5 and p.substitution_charges == 2)

	_reset(p)
	p.global_position = start
	p._sub_buffer = PlayerController.SUB_WINDOW
	var nul := not p.take_hit(8.0, Vector2.RIGHT, 180.0, null)
	ck.call("sub: a null attacker is handled", nul and p.substitution_charges == 2)
	_reset(p)
	p.global_position = start
	att.queue_free()


func _has_child_named(n: Node, prefix: String) -> bool:
	for c in n.get_children():
		if str(c.name).begins_with(prefix):
			return true
	return false


func test_kunai(p: PlayerController, arena: Node) -> void:
	_reset(p)
	var start := p.global_position
	var k := BanditKunai.spawn(arena, start + Vector2(-200, 0), Vector2.RIGHT, null, p)
	var hp := p.health
	for i in 80:
		k.step(1.0 / 60.0)
		if k.hit_result != "":
			break
	ck.call("kunai: flies at the player and lands a hit", k.hit_result == "hit" and p.health < hp, k.hit_result)
	_reset(p)
	p.state = PlayerController.State.DODGE
	var k2 := BanditKunai.spawn(arena, start + Vector2(-200, 0), Vector2.RIGHT, null, p)
	var hp2 := p.health
	for i in 80:
		k2.step(1.0 / 60.0)
		if k2.hit_result != "":
			break
	ck.call("kunai: a dodging player evades it", k2.hit_result == "evaded" and p.health == hp2, k2.hit_result)
	p.state = PlayerController.State.IDLE
	_reset(p)
	var k3 := BanditKunai.spawn(arena, start + Vector2(-200, 0), Vector2.LEFT, null, p)
	for i in 120:
		k3.step(1.0 / 60.0)
		if k3.hit_result != "":
			break
	ck.call("kunai: one thrown away from the player ends by wall or range, never a hit", k3.hit_result in ["wall", "range"], k3.hit_result)
	_reset(p)
	p._sub_buffer = PlayerController.SUB_WINDOW
	var att := _dummy(arena, start + Vector2(-200, 0))
	var k4 := BanditKunai.spawn(arena, start + Vector2(-200, 0), Vector2.RIGHT, att, p)
	for i in 80:
		k4.step(1.0 / 60.0)
		if k4.hit_result != "":
			break
	ck.call("kunai: a timed L2 swaps away from a kunai (one charge, no damage)", k4.hit_result == "evaded" and p.substitution_charges == 2 and p.substitution_count >= 1, k4.hit_result)
	att.queue_free()
	_reset(p)
	p.global_position = start


func _find_bandit(arena: Node) -> Node:
	for n in arena.get_tree().get_nodes_in_group("enemy"):
		if n is Bandit:
			return n
	return null


func test_throw(p: PlayerController, arena: Node) -> void:
	var b := _find_bandit(arena)
	ck.call("throw: a Bandit exists in the arena", b != null)
	if b == null:
		return
	b._player = p
	b.sees_player = true
	b._throw_cooldown = 0.0
	b._atk_cooldown = 0.0
	b._begin_throw()
	ck.call("throw: begin enters ATTACK / THROW_WINDUP", b.state == Bandit.State.ATTACK and b.atk_phase == Bandit.AtkPhase.THROW_WINDUP)
	ck.call("throw: progress starts at 0", b.get_throw_progress() <= 0.01)
	var before: int = b.kunai_thrown
	var t := 0.0
	while b.atk_phase == Bandit.AtkPhase.THROW_WINDUP and t < 2.0:
		b._tick_throw(0.02)
		t += 0.02
	ck.call("throw: the windup releases the first kunai of the combo", b.kunai_thrown == before + 1 and b.atk_phase == Bandit.AtkPhase.THROW_GAP)
	t = 0.0
	while b.atk_phase == Bandit.AtkPhase.THROW_GAP and t < 2.0:
		b._tick_throw(0.02)
		t += 0.02
	ck.call("throw: the combo is three kunai, then recovery", b.kunai_thrown == before + 3 and b.atk_phase == Bandit.AtkPhase.THROW_RECOVERY)
	ck.call("throw: progress is at the release point entering recovery", absf(b.get_throw_progress() - Bandit.THROW_RELEASE_AT) < 0.05)
	t = 0.0
	while b.atk_phase == Bandit.AtkPhase.THROW_RECOVERY and t < 2.0:
		b._tick_throw(0.02)
		t += 0.02
	ck.call("throw: recovery ends, cooldown starts, bandit resumes approach", b.atk_phase == Bandit.AtkPhase.NONE and b._throw_cooldown > 0.0 and b.state == Bandit.State.APPROACH)
	ck.call("throw: a cooling-down bandit does not throw again", not b._can_throw(300.0))
	b._throw_cooldown = 0.0
	b._atk_cooldown = 0.0
	ck.call("throw: too close (melee range) is not a throw", not b._can_throw(100.0))
	ck.call("throw: too far is not a throw", not b._can_throw(900.0))
	b.sees_player = false
	ck.call("throw: no sight means no throw", not b._can_throw(300.0))
	for c in arena.get_children():
		if c is BanditKunai:
			c.queue_free()


func test_art() -> void:
	var f := FileAccess.open("res://assets/characters/bandit/bandit_128.art.json", FileAccess.READ)
	ck.call("art: bandit art json readable", f != null)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var anims: Dictionary = d.get("animations", {})
	ck.call("art: throw animation registered, non-looping", anims.has("throw") and not bool(anims["throw"].get("loop", true)))
	if not anims.has("throw"):
		return
	var frames: Dictionary = anims["throw"].get("frames", {})
	var all_ok := frames.size() == 8
	var counts := {}
	for dir in frames:
		counts[(frames[dir] as Array).size()] = true
		for path in frames[dir]:
			if not FileAccess.file_exists("res://assets/characters/bandit/" + str(path)):
				all_ok = false
	ck.call("art: all 8 directions have throw frames that exist, same count each", all_ok and counts.size() == 1, str(counts))
