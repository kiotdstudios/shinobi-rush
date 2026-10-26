extends RefCounted
## Bandits live in the world like the player does: two rival crews, crew-aware targeting, kunai that hit whoever they
## meet, cliff climbing, melee only on the same level, ryo pouches, gourd looting and drinking.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	await _in_arena(root)
	await _in_blightwood(root)


func _bandit(arena: TrainingArena, crew: int, at: Vector2) -> Bandit:
	var b := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	b.crew_id = crew
	b.position = at
	b.patrol_points = PackedVector2Array([at])
	arena.add_child(b)
	b.nav = arena.nav
	return b


func _clear_pouches(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(RyoPouch.GROUP):
		n.free()


func _in_arena(root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 4:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.autosave = false
	var p := main.get_node("TrainingArena/Player") as PlayerController
	p.set_physics_process(false)
	p.global_position = WorldScale.BANDIT_HOME + Vector2(-2600, 600)
	ck.call("bandit world: the plain arena still stands up exactly one bandit", tree.get_nodes_in_group("enemy").size() == 1)
	var home := WorldScale.BANDIT_HOME
	var a := arena.get_node("Bandit") as Bandit
	a.global_position = home
	var mate := _bandit(arena, 0, home + Vector2(0, 90))
	var rival := _bandit(arena, 1, home + Vector2(220, 0))
	for n in [a, mate, rival]:
		(n as Bandit).set_physics_process(false)
	for i in 3:
		await tree.process_frame

	ck.call("bandit world: two crews with their own name and colour", Bandit.CREWS.size() == 2 and Bandit.crew_info(0).name != Bandit.crew_info(1).name)
	ck.call("bandit world: rival crews are hostile, crewmates are not", Combatants.hostile(a, rival) and not Combatants.hostile(a, mate))
	ck.call("bandit world: every bandit is hostile to the player", Combatants.hostile(a, p) and Combatants.hostile(rival, p))
	ck.call("bandit world: a rival's body still blocks", not a.get_collision_exceptions().has(rival) and not rival.get_collision_exceptions().has(a))
	ck.call("bandit world: the crew recolour is a shader on the Jade Fang only", rival.visual.actor.sprite.material is ShaderMaterial and a.visual.actor.sprite.material == null)

	# --- targeting
	a._player = null
	a.state = Bandit.State.PATROL
	a._face(Vector2.RIGHT * 10.0)
	a._find_player()
	ck.call("bandit world: a bandit in sight of a rival picks the rival, not his crewmate", a._player == rival, str(a._player))
	rival._player = null
	rival._face(Vector2.LEFT * 10.0)
	rival._find_player()
	ck.call("bandit world: the rival picks one of the Red Scarves back", rival._player == a or rival._player == mate, str(rival._player))
	a._player = p
	a.state = Bandit.State.PATROL
	a.take_hit(4.0, Vector2.RIGHT, 0.0, rival)
	ck.call("bandit world: whoever wounds him becomes his target", a._player == rival and a.last_attacker == rival)
	a.hp = a.max_hp
	a.take_hit(4.0, Vector2.RIGHT, 0.0, mate)
	ck.call("bandit world: a crewmate's stray blade does not turn him on his own crew", a._player == rival)
	a.hp = a.max_hp
	a.state = Bandit.State.PATROL

	# --- kunai: hits the first fighter on its line, never the thrower
	var behind := a.global_position + Vector2(-60, 0)
	var kn := BanditKunai.spawn(arena, behind, Vector2.RIGHT, a, rival, 6.0)
	kn.set_physics_process(false)
	var rival_hp := rival.hp
	var t := 0.0
	while is_instance_valid(kn) and kn.hit_result in ["", "evaded"] and t < 2.0:
		kn.step(0.02)
		t += 0.02
	ck.call("bandit world: a kunai thrown from behind passes its own thrower", is_equal_approx(a.hp, a.max_hp))
	ck.call("bandit world: the kunai lands on the rival", rival.hp < rival_hp)
	rival.hp = rival.max_hp
	rival.state = Bandit.State.PATROL
	var kn2 := BanditKunai.spawn(arena, a.global_position + Vector2(0, 40), Vector2.DOWN, a, p, 6.0)
	kn2.set_physics_process(false)
	var mate_hp := mate.hp
	t = 0.0
	while is_instance_valid(kn2) and kn2.hit_result in ["", "evaded"] and t < 2.0:
		kn2.step(0.02)
		t += 0.02
	ck.call("bandit world: a crewmate standing in the line takes the blade (it hits whoever it meets)", mate.hp < mate_hp)
	mate.hp = mate.max_hp
	mate.state = Bandit.State.PATROL

	# --- melee only on the same level
	ck.call("bandit world: same level by default", Combatants.same_level(a, rival))
	rival.elevation = Combatants.MELEE_LEVEL_GAP
	ck.call("bandit world: a fighter up on a landing is out of blade reach", not Combatants.same_level(a, rival))
	a._player = rival
	rival.global_position = a.global_position + Vector2(40, 0)
	a._atk_dir = Vector2.RIGHT
	a._atk_hit_done = [false, false, false]
	rival_hp = rival.hp
	a._try_hit(0)
	ck.call("bandit world: his swing does not reach a rival above him", is_equal_approx(rival.hp, rival_hp))
	rival.elevation = 0.0
	a._try_hit(0)
	ck.call("bandit world: the same swing lands at the same level", rival.hp < rival_hp)
	rival.global_position = home + Vector2(220, 0)
	rival.hp = rival.max_hp
	rival.state = Bandit.State.PATROL

	# --- a fallen bandit drops his purse; the first fighter to reach it takes it
	_clear_pouches(tree)
	rival.ryo = 15
	rival.take_damage(9999.0, Vector2.RIGHT, 0.0, 0.0, a)
	var pouches := tree.get_nodes_in_group(RyoPouch.GROUP)
	var pouch: RyoPouch = pouches[0] if pouches.size() == 1 else null
	ck.call("bandit world: a defeated bandit drops his ryo as a pouch", pouch != null and pouch.amount == 15 and rival.ryo == 0)
	ck.call("bandit world: the dead do not pick it up", pouch != null and not pouch.can_take(rival))
	rival.queue_free()  # the body would otherwise stand between him and the loot below
	await tree.process_frame
	if pouch != null:
		pouch.global_position = a.global_position + Vector2(160, 0)
	for g in tree.get_nodes_in_group(HealthGourd.GROUP) + tree.get_nodes_in_group(HealthGourd.CHAKRA_GROUP):
		(g as HealthGourd).available = false  # the layout's own gourds would compete with the loot under test
	ck.call("bandit world: crewmates slip past each other", a.get_collision_exceptions().has(mate) and mate.get_collision_exceptions().has(a))
	a._player = p
	a.state = Bandit.State.PATROL
	a.sees_player = false
	a.senses_player = false
	var ryo_before := a.ryo
	a.set_physics_process(true)
	t = 0.0
	while is_instance_valid(pouch) and t < 6.0:
		await tree.physics_frame
		t += 1.0 / 60.0
	ck.call("bandit world: an idle bandit goes for loot he can see and pockets it", not is_instance_valid(pouch) and a.ryo == ryo_before + 15, "ryo %d->%d after %.1fs" % [ryo_before, a.ryo, t])
	a.set_physics_process(false)

	# --- gourds: he tucks one in his belt, then drinks it when hurt
	var gourd := HealthGourd.new()
	gourd.kind = "health"
	gourd.name = "TestGourd"
	arena.add_child(gourd)
	gourd.global_position = a.global_position + Vector2(-140, 0)
	a.state = Bandit.State.PATROL
	a.loot_target = null
	a._loot_scan = 0.0
	a.health_gourds = 0
	a.set_physics_process(true)
	t = 0.0
	while a.health_gourds == 0 and t < 6.0:
		await tree.physics_frame
		t += 1.0 / 60.0
	a.set_physics_process(false)
	ck.call("bandit world: he takes a health gourd off the ground", a.health_gourds == 1 and not gourd.available, "%.1fs" % t)
	ck.call("bandit world: he will not hoard past what he can carry", not a._loot_wanted(gourd))
	a.hp = a.max_hp * 0.2
	var hp0 := a.hp
	a.state = Bandit.State.PATROL
	a.atk_phase = Bandit.AtkPhase.NONE
	ck.call("bandit world: badly hurt, he puts the gourd to his lips", a._tick_self_care(0.01) and a.drinking == "health" and a.health_gourds == 0)
	var drink := float(a.profile.drink_time)
	a._tick_self_care(drink * 0.5)
	ck.call("bandit world: drinking roots him in place", a.velocity == Vector2.ZERO and a.drinking == "health")
	a._tick_self_care(drink)
	ck.call("bandit world: the drink heals a quarter of his health", is_equal_approx(a.hp, hp0 + a.max_hp * Bandit.GOURD_SHARE) and a.gourds_drunk == 1 and a.drinking == "")
	a.health_gourds = 1
	a.hp = a.max_hp * 0.2
	a._tick_self_care(0.01)
	a.take_hit(1.0, Vector2.RIGHT, 0.0, p)
	ck.call("bandit world: a hit knocks the gourd from his lips", a.drinking == "")
	gourd.queue_free()

	_clear_pouches(tree)
	for n in tree.get_nodes_in_group("enemy"):
		if n != a:
			n.queue_free()
	main.queue_free()
	await tree.process_frame


func _in_blightwood(root: Node) -> void:
	var was_enabled := BlightwoodMap.enabled
	BlightwoodMap.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 8:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.autosave = false
	var p := tree.get_first_node_in_group("player") as PlayerController
	p.set_physics_process(false)
	var crews := [0, 0]
	for e in tree.get_nodes_in_group("enemy"):
		if e is Bandit and arena.is_ancestor_of(e):
			crews[(e as Bandit).crew_id] += 1
	ck.call("bandit world: the Blightwood map stands up four bandits, two per crew", crews == [2, 2], str(crews))
	var first := arena.get_node_or_null("Bandit") as Bandit
	ck.call("bandit world: the original Red Scarf is still 'Bandit' at the far-side home", first != null and first.crew_id == 0 and first.global_position.distance_to(WorldScale.BANDIT_HOME) < 150.0)

	# --- a downed player drops half his purse where he fell
	_clear_pouches(tree)
	p.ryo = 40
	p._hit_invuln = 0.0
	var fell := p.global_position
	p.take_hit(9999.0, Vector2.RIGHT, 0.0, null)
	var pouches := tree.get_nodes_in_group(RyoPouch.GROUP)
	var pouch: RyoPouch = pouches[0] if pouches.size() == 1 else null
	ck.call("bandit world: a downed player drops half his ryo where he fell", pouch != null and pouch.amount == 20 and p.ryo == 20 and pouch.global_position.distance_to(fell) < 1.0)
	_clear_pouches(tree)

	# --- a bandit walks the nav up the earth stairs onto the cliff landing
	var zone: CliffElevation
	for o in arena.placed.objects:
		if o.id == "earth_stairs_se" and not o.nodes.is_empty():
			zone = o.nodes.back() as CliffElevation
	ck.call("bandit world: the map has its cliff stairs", zone != null)
	if zone != null:
		var route := TrainingArena.climb_route(zone)
		var landing: Vector2 = (route[0] as PackedVector2Array)[2]
		var start := zone.to_global(zone.mouth) + Vector2(-150, 0)
		ck.call("bandit world: the nav routes from the ground onto the landing", not arena.nav.find_path(start, landing).is_empty())
		for e in tree.get_nodes_in_group("enemy"):
			if e != first:
				e.queue_free()
		first.set_physics_process(false)
		first.global_position = start
		first.elevation = 0.0
		for i in 2:
			await tree.physics_frame
		var t := 0.0
		var arrived := false
		while t < 12.0 and not arrived:
			arrived = first._follow(landing, first.chase_speed, 1.0 / 60.0, 14.0, false)
			first.move_and_slide()
			ShrineElevation.update_actor(first, 1.0 / 60.0)
			await tree.physics_frame
			t += 1.0 / 60.0
		ck.call("bandit world: the bandit climbs the stairs to the landing", arrived, "at %s after %.1fs" % [str(first.global_position), t])
		ck.call("bandit world: up there he stands at the cliff height", is_equal_approx(first.elevation, zone.height), "%.1f / %.1f" % [first.elevation, zone.height])
		ck.call("bandit world: the player below is not in blade reach", not Combatants.same_level(first, p))
	main.queue_free()
	await tree.process_frame
	BlightwoodMap.enabled = was_enabled
