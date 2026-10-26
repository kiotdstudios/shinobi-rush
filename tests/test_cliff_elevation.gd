extends RefCounted
class TestActor extends CharacterBody2D:
	var elevation := 0.0

func run(ck: Callable, root: Node) -> void:
	var zone := CliffElevation.new()
	zone.position = Vector2(3000, 3000)
	zone.configure({"ramp_mouth": Vector2.ZERO, "ramp_top": Vector2(72, -36), "ramp_half": Vector2(36, 18), "rise": 66.0})
	zone.landing = PackedVector2Array([zone.top - zone.half_width, zone.top + zone.half_width, zone.top + zone.half_width + Vector2(100, -50), zone.top - zone.half_width + Vector2(100, -50)])
	root.add_child(zone)
	ck.call("cliff elevation: registers its live terrain zone", ShrineElevation.terrain_zones.has(zone))
	ck.call("cliff elevation: mouth stays at ground height", is_zero_approx(zone.elevation_at(zone.mouth)))
	var monotone := true
	var last := 0.0
	for i in range(1, 100):
		var e := zone.elevation_at(zone.mouth.lerp(zone.top, float(i) / 100.0))
		monotone = monotone and e >= last and e - last < 1.0
		last = e
	ck.call("cliff elevation: smooth monotone rise without a top-step snap", monotone)
	var center := zone.top + Vector2(30, -15)
	ck.call("cliff elevation: terrace remains at full height", is_equal_approx(zone.elevation_at(center), zone.height))
	ck.call("cliff elevation: flat step across its entire width", is_equal_approx(zone.elevation_at(zone.mouth.lerp(zone.top, 0.5) + zone.half_width * 0.8), zone.height * 0.5))
	ck.call("cliff elevation: unrelated ground remains level", is_zero_approx(zone.elevation_at(Vector2(-500, 0))))
	ck.call("cliff elevation: rim and stair sides have physical collision", zone.edge_body != null and zone.edge_body.get_child_count() >= 4)
	var actor := TestActor.new()
	root.add_child(actor)
	var ledge := Sprite2D.new()
	root.add_child(ledge)
	zone.occluders.append(ledge)
	actor.position = zone.to_global(center)
	ShrineElevation.update_actor(actor, 0.01)
	ck.call("cliff elevation: actor rise respects the shared speed cap", is_equal_approx(actor.elevation, ShrineElevation.RATE * 0.01))
	ShrineElevation.update_actor(actor, 1.0)
	ck.call("cliff elevation: actor reaches and holds terrace height", is_equal_approx(actor.elevation, zone.height) and is_equal_approx(ShrineElevation.target_at(actor.global_position), zone.height))
	ck.call("cliff elevation: ledge cannot hide actor on upper landing", ledge.z_index == -1)
	actor.position = zone.to_global(zone.mouth)
	ShrineElevation.update_actor(actor, 1.0)
	ck.call("cliff elevation: descending returns actor to ground", is_zero_approx(actor.elevation))
	ck.call("cliff elevation: ledge ground sorting restored after descent", ledge.z_index == 0)
	ledge.free()
	zone.free()
	ck.call("cliff elevation: deleting terrain removes its height zone", not ShrineElevation.terrain_zones.has(zone))
	actor.free()
	await _seams(ck, root)
	_remote_shrine(ck, root)
	await _real_player(ck, root)
	await _in_map(ck, root)

func _real_player(ck: Callable, root: Node) -> void:
	var was_enabled := BlightwoodMap.enabled
	BlightwoodMap.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 4:
		await tree.process_frame
	var player := tree.get_first_node_in_group("player") as PlayerController
	var arena := main.get_node("TrainingArena") as TrainingArena
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	var zone := CliffElevation.new()
	zone.position = Vector2(850, 700)
	zone.configure({"ramp_mouth": Vector2.ZERO, "ramp_top": Vector2(72, -36), "ramp_half": Vector2(36, 18), "rise": 66.0})
	for n in arena.find_children("*", "StaticBody2D", true, false):
		(n as StaticBody2D).collision_layer = 0
	zone.landing = PackedVector2Array([zone.top - zone.half_width, zone.top + zone.half_width, zone.top + zone.half_width + Vector2(100, -50), zone.top - zone.half_width + Vector2(100, -50)])
	arena.add_child(zone)
	for i in 3:
		await tree.physics_frame
	player.set_physics_process(false)
	var reached := true
	var max_rise := 0.0
	player.global_position = zone.to_global(zone.mouth)
	player.elevation = 0.0
	var run := zone.top - zone.mouth
	for i in 40:
		var previous := player.elevation
		player.velocity = run / 40.0 * 60.0
		player.move_and_slide()
		player._follow_elevation(1.0 / 60.0)
		max_rise = maxf(max_rise, player.elevation - previous)
		await tree.physics_frame
	reached = player.global_position.distance_to(zone.to_global(zone.top)) < 5.0
	ck.call("cliff player: physically traverses the complete ramp", reached, str(player.global_position) + " expected " + str(zone.to_global(zone.top)))
	ck.call("cliff player: climbs with bounded visual rise", max_rise > 0.0 and max_rise <= ShrineElevation.RATE / 60.0 + 0.01)
	ck.call("cliff player: feet and camera stay aligned on the terrace", is_equal_approx(player.elevation, zone.height) and is_equal_approx(player.visual.position.y, -zone.height) and is_equal_approx(player.camera.position.y, -zone.height))
	var mid := zone.mouth.lerp(zone.top, 0.5)
	var sideways := zone.half_width.normalized() * 160.0
	ck.call("cliff player: stair side prevents walking through the cliff face", player.test_move(Transform2D(0.0, zone.to_global(mid)), sideways))
	player.global_position = zone.to_global(zone.top)
	for i in 40:
		player.velocity = -run / 40.0 * 60.0
		player.move_and_slide()
		player._follow_elevation(1.0 / 60.0)
		await tree.physics_frame
	ck.call("cliff player: walks down and returns to lower ground", player.global_position.distance_to(zone.to_global(zone.mouth)) < 5.0 and player.elevation < 1.0)
	main.queue_free()
	for i in 3:
		await tree.process_frame
	BlightwoodMap.enabled = was_enabled

const FINAL_DEF := {"ramp_mouth": Vector2.ZERO, "ramp_top": Vector2(72, -36), "ramp_half": Vector2(36, 18), "rise": 66.0}
const FINAL_LANDING := [Vector2(36, -54), Vector2(108, -18), Vector2(158, -43), Vector2(86, -79)]

func _final_zone(root: Node, head_shift: Vector2) -> CliffElevation:
	var zone := CliffElevation.new()
	zone.position = Vector2(-4000, 4000)
	var def := FINAL_DEF.duplicate()
	def.landing = [FINAL_LANDING[0] + head_shift, FINAL_LANDING[1] + head_shift, FINAL_LANDING[2], FINAL_LANDING[3]]
	zone.configure(def)
	root.add_child(zone)
	return zone

## Largest target change between 0.4px samples walked up the ramp and onto the landing, on three lanes.
func _max_target_step(zone: CliffElevation) -> float:
	var run := zone.top - zone.mouth
	var worst := 0.0
	for lane in [-0.8, 0.0, 0.8]:
		var last := zone.elevation_at(zone.mouth + zone.half_width * lane)
		for i in range(1, 301):
			var e := zone.elevation_at(zone.mouth + zone.half_width * lane + run * (float(i) / 200.0))
			worst = maxf(worst, absf(e - last))
			last = e
	return worst

## Same collider contract as PlayerController: a FOOTPRINT rectangle whose bottom edge sits on the feet.
func _feet_probe(root: Node) -> CharacterBody2D:
	var probe := CharacterBody2D.new()
	probe.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = WorldScale.FOOTPRINT
	shape.shape = rect
	shape.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	probe.add_child(shape)
	probe.collision_layer = 0
	probe.collision_mask = ShrineElevation.EDGE_LAYER
	root.add_child(probe)
	return probe

## Where the feet end up after pushing the probe from `from` along `motion` (zone-local in, zone-local out).
func _slide_end(probe: CharacterBody2D, zone: CliffElevation, from: Vector2, motion: Vector2) -> Vector2:
	var col := KinematicCollision2D.new()
	if probe.test_move(Transform2D(0.0, zone.to_global(from)), motion, col):
		return from + col.get_travel()
	return from + motion

func _seams(ck: Callable, root: Node) -> void:
	var probe := _feet_probe(root)
	var run_dir := (FINAL_DEF.ramp_top as Vector2).normalized()
	var cases := {"exact": Vector2.ZERO, "float jitter": Vector2(1e-4, -1e-4), "half pixel into ramp": -run_dir * 0.5, "four pixels into ramp": -run_dir * 4.0, "half pixel short of top": run_dir * 0.5}
	for label: String in cases:
		var zone := _final_zone(root, cases[label])
		await root.get_tree().physics_frame
		await root.get_tree().physics_frame
		var run := zone.top - zone.mouth
		var open := true
		for lane in [-0.15, 0.0, 0.15]:
			var from: Vector2 = zone.mouth + run * 0.85 + zone.half_width * lane
			var to: Vector2 = zone.top + run * 0.2 + zone.half_width * lane
			open = open and not probe.test_move(Transform2D(0.0, zone.to_global(from)), to - from)
		ck.call("cliff seam (%s): top opening stays open for the player footprint" % label, open)
		var step := _max_target_step(zone)
		ck.call("cliff seam (%s): no height snap crossing ramp to landing" % label, step < 1.0, "max %.2f px per 0.4 px" % step)
		var terrace := zone.top + run * 0.15
		ck.call("cliff seam (%s): back rim stays closed" % label, probe.test_move(Transform2D(0.0, zone.to_global(terrace)), run))
		zone.free()
	var zone := _final_zone(root, Vector2.ZERO)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	var run := zone.top - zone.mouth
	var mid := zone.mouth + run * 0.5
	var across := zone.half_width.normalized() * 120.0
	var sides_hold := true
	for side in [-1.0, 1.0]:
		var outside: Vector2 = mid + across * side
		sides_hold = sides_hold and probe.test_move(Transform2D(0.0, zone.to_global(outside)), -across * side * 0.9)
	ck.call("cliff footprint: ground-level side entry onto the stairs is blocked on both sides", sides_hold)
	var lowest := INF
	for i in 16:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 16.0)
		lowest = minf(lowest, zone.elevation_at(_slide_end(probe, zone, mid, dir * 120.0)) if dir.dot(run) > -0.5 else zone.height * 0.5)
	ck.call("cliff footprint: pushing off the ramp mid-climb keeps the feet on the stairs", lowest >= zone.height * 0.45, "lowest %.1f" % lowest)
	var top_lowest := INF
	var terrace := zone.top + run * 0.15
	for i in 16:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 16.0)
		if dir.dot(run.normalized()) < -0.7:
			continue
		top_lowest = minf(top_lowest, zone.elevation_at(_slide_end(probe, zone, terrace, dir * 160.0)))
	ck.call("cliff footprint: walls keep the feet on the terrace (no fall to ground)", top_lowest >= zone.height * 0.9, "lowest %.1f" % top_lowest)
	zone.free()
	probe.free()

func _remote_shrine(ck: Callable, root: Node) -> void:
	var shrine := DynamicShrine.new()
	shrine.position = Vector2(4000, -4000)
	root.add_child(shrine)
	var zone := _final_zone(root, Vector2.ZERO)
	var actor := TestActor.new()
	root.add_child(actor)
	actor.global_position = zone.to_global(Vector2(97, -40))
	ShrineElevation.update_actor(actor, 1.0)
	ck.call("cliff elevation: actor on a cliff terrace reaches its height", is_equal_approx(actor.elevation, zone.height))
	ck.call("cliff elevation: a remote shrine keeps the actor at ground level", not bool(shrine._upper_actors.get(actor.get_instance_id(), false)) and actor.get_collision_exceptions().is_empty())
	ck.call("cliff elevation: a remote shrine does not switch to upper sorting", not shrine.sort_upper)
	actor.free()
	zone.free()
	shrine.free()

## The placed Blightwood stairs with every real collider live: climb from the mouth to the top and back.
func _in_map(ck: Callable, root: Node) -> void:
	var was_enabled := BlightwoodMap.enabled
	BlightwoodMap.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 8:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.autosave = false
	var player := tree.get_first_node_in_group("player") as PlayerController
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	var zone: CliffElevation
	for o in arena.placed.objects:
		if o.id == "earth_stairs_se" and not o.nodes.is_empty():
			zone = o.nodes.back() as CliffElevation
	ck.call("cliff map: the placed stairs carry a live elevation zone", zone != null and ShrineElevation.terrain_zones.has(zone))
	if zone == null:
		main.queue_free()
		BlightwoodMap.enabled = was_enabled
		return
	ck.call("cliff map: the stairs are linked to their flanking ledges", not zone.ground_bodies.is_empty() and not zone.occluders.is_empty())
	player.set_physics_process(false)
	player.global_position = zone.to_global(zone.mouth)
	player.elevation = 0.0
	for i in 3:
		await tree.physics_frame
	var run := zone.top - zone.mouth
	var monotone := true
	var max_step := 0.0
	var side_blocked := true
	var ledges_ignored_on_ramp := true
	for i in 60:
		var before := player.elevation
		player.velocity = run
		player.move_and_slide()
		player._follow_elevation(1.0 / 60.0)
		monotone = monotone and player.elevation >= before - 0.001
		max_step = maxf(max_step, absf(player.elevation - before))
		if i == 30:
			var across := zone.half_width.normalized() * 120.0
			for side in [-1.0, 1.0]:
				side_blocked = side_blocked and player.test_move(player.global_transform, across * side)
			for body in zone.ground_bodies:
				ledges_ignored_on_ramp = ledges_ignored_on_ramp and player.get_collision_exceptions().has(body)
		await tree.physics_frame
	var feet := zone.to_local(player.global_position)
	ck.call("cliff map: the player climbs from the mouth to the top step", feet.distance_to(zone.top) < 5.0, str(feet) + " expected " + str(zone.top))
	ck.call("cliff map: climbing rises steadily without a snap", monotone and max_step <= ShrineElevation.RATE / 60.0 + 0.01, "max %.2f px/tick" % max_step)
	ck.call("cliff map: at the top the figure and camera stand at the cliff height", is_equal_approx(player.elevation, zone.height) and is_equal_approx(player.visual.position.y, -zone.height) and is_equal_approx(player.camera.position.y, -zone.height))
	ck.call("cliff map: stair sides still block the player mid-climb", side_blocked)
	ck.call("cliff map: flanking ledge bodies do not snag the player on the ramp", ledges_ignored_on_ramp)
	var hidden := true
	for sprite in zone.occluders:
		hidden = hidden and sprite.z_index == -1
	ck.call("cliff map: flanking ledges draw under the player at the top", hidden)
	monotone = true
	max_step = 0.0
	for i in 60:
		var before := player.elevation
		player.velocity = -run
		player.move_and_slide()
		player._follow_elevation(1.0 / 60.0)
		monotone = monotone and player.elevation <= before + 0.001
		max_step = maxf(max_step, absf(player.elevation - before))
		await tree.physics_frame
	feet = zone.to_local(player.global_position)
	ck.call("cliff map: the player walks back down to the mouth", feet.distance_to(zone.mouth) < 5.0 and player.elevation < 1.0, str(feet) + " elevation %.1f" % player.elevation)
	ck.call("cliff map: descending lowers steadily without a snap", monotone and max_step <= ShrineElevation.RATE / 60.0 + 0.01, "max %.2f px/tick" % max_step)
	var restored := true
	for body in zone.ground_bodies:
		restored = restored and not player.get_collision_exceptions().has(body)
	for sprite in zone.occluders:
		restored = restored and sprite.z_index != -1
	ck.call("cliff map: back on the ground the ledges collide and sort normally again", restored)
	main.queue_free()
	for i in 3:
		await tree.process_frame
	BlightwoodMap.enabled = was_enabled
