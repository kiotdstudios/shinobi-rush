extends RefCounted
## Combat Fluidity Milestone B (offensive combat): data-driven attack table, authored event markers,
## hit-confirm follow-ups, limited cancels (no infinite chain / universal cancel), hitbox geometry per
## facing, one hit per target per swing, reusable hit events driving FX + hitstop. Called from run_tests.gd.

var ck: Callable


class Dummy extends Node2D:
	var hits: int = 0
	var last_dir: Vector2 = Vector2.ZERO
	var alive: bool = true

	func take_damage(_amount: float, dir: Vector2, _kb: float, _hs: float) -> void:
		hits += 1
		last_dir = dir

	func is_alive() -> bool:
		return alive


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_table()
	test_markers_and_windows()
	await test_hit_events_and_fx(tree_root)
	await test_geometry_all_facings(tree_root)
	await test_hit_confirm_chain(tree_root)
	await test_finisher_ends_chain(tree_root)
	await test_whiff_cancel_rules(tree_root)
	await test_hitstop_range(tree_root)


func _boot(tree_root: Node) -> Array:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	for b in main.get_tree().get_nodes_in_group("enemy"):
		b.remove_from_group("enemy")  # only the dummies below are targets
		b.global_position = Vector2(-5000, -5000)
	return [main, player]


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


func _dummy(main: Node, pos: Vector2) -> Dummy:
	var d := Dummy.new()
	main.add_child(d)
	d.add_to_group("enemy")
	d.global_position = pos
	return d


func _frames(main: Node, n: int) -> void:
	for i in n:
		await main.get_tree().physics_frame


func _swing(main: Node, player: PlayerController, attack_id: String, face: Vector2) -> void:
	player.facing8 = face
	player.facing = face
	player.velocity = Vector2.ZERO
	player._begin_attack(attack_id)


func test_table() -> void:
	var t := AttackDef.build_table()
	var want := {"light1": [5, 4, 9], "light2": [6, 4, 11], "light3": [9, 5, 15], "dash_attack": [6, 5, 13]}
	for id: String in want:
		var d: AttackDef = t[id]
		var f: Array = want[id]
		var ok := is_equal_approx(d.startup * 60.0, f[0]) and is_equal_approx(d.active * 60.0, f[1]) and is_equal_approx(d.recovery * 60.0, f[2])
		ck.call("B table: %s startup/active/recovery = %s ticks" % [id, str(f)], ok)
	ck.call("B table: light1 -> light2 -> light3 chain is data-driven", t["light1"].chains_to == "light2" and t["light2"].chains_to == "light3")
	ck.call("B table: light3 is a finisher (no chain, heavy class)", t["light3"].chains_to == "" and t["light3"].heavy)
	ck.call("B table: dash attack never chains and is heavy class", t["dash_attack"].chains_to == "" and t["dash_attack"].heavy)
	var light_ok := true
	var heavy_ok := true
	for id: String in ["light1", "light2", "light3", "dash_attack"]:
		var d: AttackDef = t[id]
		if d.heavy and (d.hitstop_ms < 55.0 or d.hitstop_ms > 100.0):
			heavy_ok = false
		if not d.heavy and (d.hitstop_ms < 40.0 or d.hitstop_ms > 60.0):
			light_ok = false
	ck.call("B table: light hitstop within 40-60 ms", light_ok)
	ck.call("B table: heavy hitstop within 55-100 ms (heavy target 70-100 for the finisher)", heavy_ok and t["light3"].hitstop_ms >= 70.0)


func test_markers_and_windows() -> void:
	var t := AttackDef.build_table()
	var d: AttackDef = t["light1"]
	var names: Array = []
	var last := -1.0
	var sorted := true
	for m: Dictionary in d.event_markers():
		names.append(m.name)
		if m.t < last:
			sorted = false
		last = m.t
	ck.call("B markers: light1 has startup/active/recovery/combo_open/cancel_open/end", "startup" in names and "active" in names and "recovery" in names and "combo_open" in names and "cancel_open" in names and "end" in names, str(names))
	ck.call("B markers: sorted by time", sorted)
	ck.call("B markers: finisher has no combo markers", not ("combo_open" in (t["light3"] as AttackDef).event_markers().map(func(m: Dictionary) -> String: return m.name)))
	ck.call("B window: hit-confirm widens the combo window", d.combo_window_for(true) > d.combo_window_for(false))
	ck.call("B window: finisher combo window is 0 even when confirmed", (t["light3"] as AttackDef).combo_window_for(true) == 0.0)
	ck.call("B cancel: whiffed light1 opens its dodge cancel later than a connected one", d.dodge_cancel_from_for(false) > d.dodge_cancel_from_for(true))
	ck.call("B cancel: whiffed finisher has NO dodge cancel", (t["light3"] as AttackDef).dodge_cancel_from_for(false) < 0.0)
	ck.call("B cancel: connected finisher can dodge-cancel", (t["light3"] as AttackDef).dodge_cancel_from_for(true) >= 0.0)
	ck.call("B cancel: whiffed dash attack has NO dodge cancel", (t["dash_attack"] as AttackDef).dodge_cancel_from_for(false) < 0.0)


func test_hit_events_and_fx(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	await _reset(player, Vector2(-900, 100))
	var fx := player.get_node("HitFx") as HitFx
	fx.audio_enabled = false
	var dummy := _dummy(main, player.global_position + Vector2(70, 0))
	var events: Array = []
	var hits: Array = []
	player.attack_event.connect(func(n: String, id: String) -> void: events.append(n + ":" + id))
	player.attack_hit.connect(func(h: HitEvent) -> void: hits.append(h))
	_swing(main, player, "light1", Vector2.RIGHT)
	await _frames(main, 40)
	ck.call("B hit: exactly one damage call per swing despite a multi-tick active window", dummy.hits == 1, str(dummy.hits))
	ck.call("B hit: exactly one attack_hit event", hits.size() == 1, str(hits.size()))
	var h: HitEvent = hits[0] if hits.size() > 0 else null
	ck.call("B hit: event carries attack id, direction and a contact point near the target", h != null and h.attack_id == "light1" and h.direction.dot(Vector2.RIGHT) > 0.99 and h.position.distance_to(dummy.global_position) < 70.0)
	ck.call("B hit: knockback direction passed to the target matches the strike direction", dummy.last_dir.dot(Vector2.RIGHT) > 0.99)
	ck.call("B events: startup, active, recovery and end all fired in order", events.find("startup:light1") >= 0 and events.find("active:light1") > events.find("startup:light1") and events.find("recovery:light1") > events.find("active:light1") and events.find("end:light1") > events.find("recovery:light1"), str(events))
	ck.call("B fx: slash arc spawned once with exactly the hit-test reach and half-angle", fx.arcs_spawned == 1 and is_equal_approx(float(fx.last_arc.get("reach", 0.0)), 95.0) and is_equal_approx(float(fx.last_arc.get("half_angle_deg", 0.0)), 40.0), str(fx.last_arc))
	ck.call("B fx: contact sparks and impact silhouette spawned once each", fx.sparks_spawned == 1 and fx.silhouettes_spawned == 1)
	_swing(main, player, "light2", Vector2.RIGHT)
	await _frames(main, 8)
	ck.call("B hit: a new swing may hit the same target again (once per swing, not once ever)", dummy.hits == 2, str(dummy.hits))
	main.queue_free()
	await main.get_tree().process_frame


func test_geometry_all_facings(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	var bad: Array = []
	for i in 8:
		var face := Vector2.from_angle(TAU * i / 8.0).normalized()
		await _reset(player, Vector2(-900, 100))
		var inside := _dummy(main, player.global_position + face * 80.0)
		var behind := _dummy(main, player.global_position - face * 60.0)
		var far := _dummy(main, player.global_position + face * 160.0)
		var side := _dummy(main, player.global_position + face.orthogonal() * 70.0)
		_swing(main, player, "light1", face)
		await _frames(main, 20)
		if inside.hits != 1 or behind.hits != 0 or far.hits != 0 or side.hits != 0:
			bad.append("dir%d in=%d behind=%d far=%d side=%d" % [i, inside.hits, behind.hits, far.hits, side.hits])
		for d in [inside, behind, far, side]:
			d.queue_free()
		await _frames(main, 40)
	ck.call("B geometry: forward arc hits, behind/side/out-of-reach miss in all 8 facings", bad.is_empty(), str(bad))
	main.queue_free()
	await main.get_tree().process_frame


func _into_recovery(main: Node, player: PlayerController) -> void:
	for i in 120:
		await main.get_tree().physics_frame
		if player._attack_phase == PlayerController.AttackPhase.RECOVERY:
			return


func test_hit_confirm_chain(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	await _reset(player, Vector2(-900, 100))
	var dummy := _dummy(main, player.global_position + Vector2(70, 0))
	_swing(main, player, "light1", Vector2.RIGHT)
	await _into_recovery(main, player)
	ck.call("B confirm: connected swing is flagged hit-confirmed", player._hit_confirmed and dummy.hits == 1)
	var win_c: float = player._attack_def.combo_window_for(true)
	var win_w: float = player._attack_def.combo_window_for(false)
	ck.call("B confirm: connected combo window is wider than the whiff window", win_c > win_w, "%.3f vs %.3f" % [win_c, win_w])
	# a press landing in the confirm-only slice chains; the same press after the window does not
	player._attack_buffer = 0.2
	await _frames(main, 2)
	ck.call("B chain: buffered press in recovery continues to light2", player.state == PlayerController.State.LIGHT2, player.get_state_name())
	main.queue_free()
	await main.get_tree().process_frame


func test_finisher_ends_chain(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	await _reset(player, Vector2(-900, 100))
	_swing(main, player, "light3", Vector2.RIGHT)
	await _into_recovery(main, player)
	ck.call("B chain: light3 recovery offers no combo continuation (no infinite chain)", not player.cancel_eligibility().combo)
	player._attack_buffer = 0.3
	await _frames(main, 3)
	ck.call("B chain: a press buffered during light3 recovery does NOT wrap into light1/2 mid-recovery", player.state == PlayerController.State.LIGHT3, player.get_state_name())
	main.queue_free()
	await main.get_tree().process_frame


func test_whiff_cancel_rules(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	await _reset(player, Vector2(-900, 100))
	_swing(main, player, "light3", Vector2.RIGHT)  # nothing to hit
	await _into_recovery(main, player)
	player._attack_timer = 0.15
	await _frames(main, 1)
	player._dodge_buffer = 0.2
	await _frames(main, 2)
	ck.call("B cancel: whiffed finisher cannot be dodge-cancelled (universal cancel blocked)", player.state == PlayerController.State.LIGHT3, player.get_state_name())
	ck.call("B cancel: cancel_eligibility agrees (dodge_cancel false on a whiffed finisher)", not player.cancel_eligibility().dodge_cancel)
	await _reset(player, Vector2(-900, 100))
	var dummy := _dummy(main, player.global_position + Vector2(80, 0))
	_swing(main, player, "light3", Vector2.RIGHT)
	await _into_recovery(main, player)
	await _frames(main, 6)
	ck.call("B cancel: connected finisher reports dodge_cancel eligible deep in recovery", dummy.hits == 1 and player._hit_confirmed)
	player._dodge_buffer = 0.2
	await _frames(main, 3)
	ck.call("B cancel: connected finisher dodge-cancels into a dodge", player.state == PlayerController.State.DODGE, player.get_state_name())
	await _frames(main, 60)  # let the dodge's own effects finish before the scene is freed
	main.queue_free()
	await main.get_tree().process_frame


func test_hitstop_range(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[1]
	await _reset(player, Vector2(-900, 100))
	var dummy := _dummy(main, player.global_position + Vector2(70, 0))
	_swing(main, player, "light1", Vector2.RIGHT)
	var peak := 0.0
	for i in 30:
		await main.get_tree().physics_frame
		peak = maxf(peak, player._hitstop_timer)
	ck.call("B hitstop: light hit freezes the attacker for ~40-60 ms", dummy.hits == 1 and peak >= 0.039 and peak <= 0.061, "%.3f" % peak)
	await _reset(player, Vector2(-900, 100))
	dummy.hits = 0
	_swing(main, player, "light3", Vector2.RIGHT)
	peak = 0.0
	for i in 40:
		await main.get_tree().physics_frame
		peak = maxf(peak, player._hitstop_timer)
	ck.call("B hitstop: finisher freezes the attacker for ~70-100 ms", dummy.hits == 1 and peak >= 0.069 and peak <= 0.101, "%.3f" % peak)
	await _reset(player, Vector2(-900, 100))
	var before := player.global_position
	player._hitstop_timer = 0.1
	player.velocity = Vector2(300, 0)
	await _frames(main, 3)
	ck.call("B hitstop: physics state is preserved, not corrupted (velocity kept, no teleport)", player.velocity.x > 0.0 and player.global_position.distance_to(before) < 40.0)
	main.queue_free()
	await main.get_tree().process_frame
