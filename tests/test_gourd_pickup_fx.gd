extends RefCounted
## Health gourd absorb animation: squash, burst, magnetic warp to the player's CURRENT chest, absorb, layered sound.
## Owner 2026-10-25: collecting a gourd now adds it to the held-items inventory instead of healing on
## pickup (see HealthGourd.collect / PlayerController.add_held_item) -- the take-it animation itself
## (squash/burst/warp/absorb timings) is unchanged and still tested here; only the stat-effect
## assertions changed (health stays put; the HUD bar no longer plays a fill since nothing moved).

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 5:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var player := arena.get_node("Player") as PlayerController
	var g := tree.get_nodes_in_group(HealthGourd.GROUP)[0] as HealthGourd
	var bar := player.get_node("HealthBar") as HealthBar

	player.global_position = g.global_position
	player.health = 50.0  # direct assignment, no health_changed signal -- bar.fraction is whatever it already was
	var bar_fraction_before := bar.fraction
	var gained := g.collect(player)
	var fx := g.fx
	ck.call("gourd fx: collecting adds 1 to the inventory, leaves HP untouched, and the pickup is used up",
		is_equal_approx(gained, 1.0) and is_equal_approx(player.health, 50.0) and player.held_items.count("health_gourd") == 1 and not g.available)
	ck.call("gourd fx: collecting starts the effect", fx != null and is_instance_valid(fx))
	if fx == null:
		main.queue_free()
		return
	fx.auto = false
	var glow0 := 1.0

	# 1. contact
	fx.advance(0.04)
	var v: Node2D = g._visual
	ck.call("gourd fx: contact - still visible, squashed down and spread wide", v.visible and v.scale.x > 1.0 and v.scale.y < 1.0, str(v.scale))
	ck.call("gourd fx: contact - glow roughly 2.5x brighter", g._glow.modulate.r >= glow0 * 2.0, str(g._glow.modulate))
	# 2. burst
	fx.advance(0.13)  # t = 0.17, end of the burst
	ck.call("gourd fx: burst - rotated 15-25 degrees and lifted off the ground", absf(rad_to_deg(v.rotation)) >= 12.0 and absf(rad_to_deg(v.rotation)) <= 28.0 and v.position.y < -HealthGourd.FLOAT_HEIGHT, "%.1f deg / y %.1f" % [rad_to_deg(v.rotation), v.position.y])
	var sparks := 0
	for q in fx.particles:
		if q.kind == "dot":
			sparks += 1
	ck.call("gourd fx: burst - 8-12 energy sparks are in the air", sparks >= 8 and sparks <= 24, str(sparks))
	# 3. warp follows the player's CURRENT position
	fx.advance(0.02)
	var early := v.global_position
	player.global_position += Vector2(260, 0)  # the player keeps running
	fx.advance(0.07)
	fx.advance(0.08)  # t = 0.34
	var chest := player.global_position + GourdPickupFx.CHEST
	var near := v.global_position.distance_to(chest)
	ck.call("gourd fx: warp - homes on where the player is NOW, not where they were", near < early.distance_to(chest) * 0.5 and near < 120.0, "%.1f" % near)
	ck.call("gourd fx: warp - shrinking toward nothing", v.scale.x < 0.5 and v.scale.y < 1.2, str(v.scale))
	ck.call("gourd fx: warp - leaves a trail", fx._history.size() >= 2)
	# 4. absorb
	fx.advance(0.03)  # t = 0.37
	var spirals := 0
	for q in fx.particles:
		if q.kind == "spiral":
			spirals += 1
	ck.call("gourd fx: absorb - 6-10 healing sparks spiral up", spirals >= 6 and spirals <= 10, str(spirals))
	ck.call("gourd fx: absorb - the gourd itself is gone", not v.visible)
	# 5. HUD -- no fill plays any more: pickup no longer heals, so there is nothing to animate.
	ck.call("gourd fx: HUD - does not start a heal-fill animation (nothing was restored)", not bar.heal_animating() and is_equal_approx(bar.fraction, bar_fraction_before))
	bar._process(0.5)
	bar._process(0.125)
	bar._process(0.2)
	bar._process(0.5)
	ck.call("gourd fx: HUD - bar stays exactly where it was through the whole take-it animation", is_equal_approx(bar.shown_fraction(), bar_fraction_before) and is_equal_approx(bar.fraction, bar_fraction_before))
	fx.advance(0.2)  # t = 0.57
	ck.call("gourd fx: pickup burst visuals are still alive at this point", not fx.finished)
	fx.advance(1.0)
	ck.call("gourd fx: it cleans itself up", fx.finished)

	# respawn is not blocked by the effect
	player.global_position = arena.get_node("Spawn").global_position
	g.respawn_left = 0.01
	await tree.create_timer(0.15).timeout
	ck.call("gourd fx: the gourd still respawns, visible and reset", g.available and g._visual.visible and is_equal_approx(g._visual.rotation, 0.0) and is_equal_approx(g._glow.modulate.r, 1.0))

	# sound
	var snd := GourdPickupFx.pickup_sound()
	var secs := float(snd.data.size()) / 2.0 / float(snd.mix_rate)
	ck.call("gourd fx: sound is one clip of about a second", secs > 0.8 and secs < 1.2, "%.2f s" % secs)
	var pcm := snd.data
	var hot := 0
	for w in [[0.0, 0.05], [0.1, 0.3], [0.15, 0.4], [0.35, 0.5], [0.6, 0.95]]:
		if _rms(pcm, snd.mix_rate, w[0], w[1]) > 0.01:
			hot += 1
	ck.call("gourd fx: all five sound layers have energy in their windows", hot == 5, str(hot))
	var peak := 0.0
	for i in range(0, pcm.size() - 1, 2):
		peak = maxf(peak, absf(float(pcm.decode_s16(i)) / 32768.0))
	ck.call("gourd fx: sound does not clip", peak < 0.99 and peak > 0.2, str(peak))

	main.queue_free()
	await tree.process_frame


func _rms(pcm: PackedByteArray, rate: int, from_s: float, to_s: float) -> float:
	var a := int(from_s * rate) * 2
	var b := mini(int(to_s * rate) * 2, pcm.size() - 2)
	var sum := 0.0
	var n := 0
	var i := a
	while i < b:
		var s := float(pcm.decode_s16(i)) / 32768.0
		sum += s * s
		n += 1
		i += 2
	return sqrt(sum / maxf(float(n), 1.0))
