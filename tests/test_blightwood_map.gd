extends RefCounted
## Blightwood starting map: terrain sampled from the owner's low-poly map, props from the reference shot.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var cells := BlightwoodMap.terrain_cells()
	for ch in ["g", "d", "s", "c", "w"]:
		ck.call("blightwood map: terrain '%s' has cells" % ch, cells[ch].size() > 100, str(cells[ch].size()))
	var spawn := BlightwoodMap.spawn_point()
	var dirt := {}
	for c: Vector2 in cells.d:
		dirt[c] = true
	ck.call("blightwood map: the spawn stands on the dirt courtyard", dirt.has(spawn), str(spawn))
	ck.call("blightwood map: every authored prop lies inside the arena", _props_inside(), "")
	var shrines := 0
	var braziers := 0
	for item: Array in BlightwoodMap.props():
		if item[0] == "ancient_shrine":
			shrines += 1
		elif item[0] == "blight_stone_brazier":
			braziers += 1
	ck.call("blightwood map: one shrine and three braziers authored", shrines == 1 and braziers == 3)
	ck.call("blightwood map: the reference fence runs are authored", BlightwoodMap.fences().size() >= 9, str(BlightwoodMap.fences().size()))

	BlightwoodMap.enabled = true
	AncientShrineSection.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 8:
		await tree.process_frame
	BlightwoodMap.enabled = false
	AncientShrineSection.enabled = false
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_blightwood_map_layout.json"
	placed.autosave = false
	ck.call("blightwood map: laid once and flagged", placed.blightwood_map_applied)
	var counts := {}
	for o in placed.objects:
		counts[o.id] = int(counts.get(o.id, 0)) + 1
	ck.call("blightwood map: exactly one Ancient Shrine", int(counts.get("ancient_shrine", 0)) == 1)
	ck.call("blightwood map: three braziers", int(counts.get("blight_stone_brazier", 0)) == 3)
	ck.call("blightwood map: the earth stairs are laid on the cliff", int(counts.get("earth_stairs_se", 0)) == 1)
	ck.call("blightwood map: two cliff faces flank the stairs", int(counts.get("cliff_ledge_se", 0)) == 2)
	_check_stairs(ck, placed)
	var stair_bodies := 0
	for o in placed.objects:
		if o.id == "earth_stairs_se":
			for n: Node in o.nodes:
				stair_bodies += _count_blocking(n)
	ck.call("blightwood map: stair run has no blocking collision (only elevation-edge rails)", stair_bodies == 0)
	ck.call("blightwood map: both earth-stair facings are in the catalog", PlacedObjects.CATALOG.has("earth_stairs_se") and PlacedObjects.CATALOG.has("earth_stairs_sw") and not PlacedObjects.CATALOG.has("blight_stairs"))
	ck.call("blightwood map: the bridge is laid", int(counts.get("bridge_medium_wood_u", 0)) == 1)
	ck.call("blightwood map: the waterfall is laid", int(counts.get("waterfall_small", 0)) == 1)
	ck.call("blightwood map: no old temple courtyard under the map", int(counts.get("temple_floor_corner_top", 0)) == 0)
	var expected_rock := 0
	for c: Vector2 in cells.c:
		if not BlightwoodMap.stair_landing().has(c):
			expected_rock += 1
	ck.call("blightwood map: cliff rock ground outside landing", int(counts.get("shore_rock_15", 0)) >= expected_rock)
	var landing_ok := true
	for c: Vector2 in BlightwoodMap.stair_landing():
		var tiles := placed.floor_tiles_in_cell(c)
		landing_ok = landing_ok and tiles.size() == 1 and str(tiles[0].id).begins_with("ground9_")
	ck.call("blightwood map: stairs end at a dirt landing", landing_ok)
	ck.call("blightwood map: no two floor tiles share a cell", _floor_count(placed) == _distinct_floor(placed), str(_floor_count(placed)))
	var voids := placed.void_cells(Rect2(-1200, -600, 2400, 1200))
	ck.call("blightwood map: no white void inside the map", voids.size() == 0, str(voids.size()))
	var player := tree.get_first_node_in_group("player") as Node2D
	ck.call("blightwood map: the player starts on the courtyard", player != null and (player.global_position - spawn).length() < 120.0)
	var data := placed.to_dict()
	ck.call("blightwood map: the flag is saved", bool(data.get("blightwood_map", false)))
	var before := placed.objects.size()
	var reloaded := placed.load_dict(data)
	ck.call("blightwood map: save then reload keeps every object", reloaded == before and placed.objects.size() == before, "%d reloaded vs %d saved" % [placed.objects.size(), before])
	BlightwoodMap.enabled = true
	BlightwoodMap.populate(arena)
	BlightwoodMap.enabled = false
	var after_braziers := 0
	for o in placed.objects:
		if o.id == "blight_stone_brazier":
			after_braziers += 1
	ck.call("blightwood map: reload does not lay it again", after_braziers == 3 and placed.objects.size() == before, "%d vs %d" % [placed.objects.size(), before])
	_check_stair_links_after_reload(ck, placed)
	await _check_bandit_climbs(ck, arena, tree)
	_check_cliffs(ck, placed, arena, cells.c)
	main.queue_free()


## Cliffs are rock-textured GROUND: no collision of their own, and you can walk (and enemies path) across them.
func _check_cliffs(ck: Callable, placed: PlacedObjects, arena: TrainingArena, cliff_cells: Array) -> void:
	var bodies := 0
	for o in placed.objects:
		if o.id == BlightwoodMap.CLIFF_TILE:
			for n: Node in o.nodes:
				bodies += _count_collision(n)
	ck.call("cliff: the rock ground tiles carry no collision", bodies == 0, str(bodies))
	var walkable := 0
	for c: Vector2 in cliff_cells:
		if arena.nav != null and arena.nav.is_walkable(c):
			walkable += 1
	var frac := float(walkable) / float(maxi(cliff_cells.size(), 1))
	ck.call("cliff: the nav treats cliff ground as walkable (%.0f%%)" % (frac * 100.0), frac >= 0.9, "%d/%d" % [walkable, cliff_cells.size()])


## The stair is two floor edges wide (72 x 36 tread), its zone matches the catalog, and the
## flanking cliff faces continue the stair-head line without walling off the run.
func _check_stairs(ck: Callable, placed: PlacedObjects) -> void:
	var def := PlacedObjects.def_of("earth_stairs_se")
	var half: Vector2 = def.ramp_half
	ck.call("stairs: tread spans two floor edges (72 x 36)", half * 2.0 == Vector2(72, 36), str(half * 2.0))
	ck.call("stairs: run climbs two floor edges", (def.ramp_top as Vector2) == Vector2(72, -36), str(def.ramp_top))
	var img := PlacedObjects.wall_texture("earth_stairs_se").get_image()
	var mouth_px: Vector2 = def.anchor
	var lo := 999
	var hi := -999
	for t in range(-80, 81):
		var x := int(mouth_px.x) + t
		var y := roundi(mouth_px.y + t * 0.5 - 4.0)
		if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height() and img.get_pixel(x, y).a > 0.0:
			lo = mini(lo, t)
			hi = maxi(hi, t)
	ck.call("stairs: the bottom tread art is 72px wide along the tile edge", absi(hi - lo + 1 - 72) <= 6, "%d..%d" % [lo, hi])
	var stair: Dictionary = {}
	for o in placed.objects:
		if o.id == "earth_stairs_se":
			stair = o
	if stair.is_empty():
		ck.call("stairs: laid on the map", false)
		return
	ck.call("stairs: mouth sits on a floor-diamond vertex", PlacedObjects.iso_vertex(stair.pos) == stair.pos, str(stair.pos))
	var zone := stair.nodes[stair.nodes.size() - 1] as CliffElevation
	ck.call("stairs: carry a live elevation zone", zone != null and zone.is_inside_tree() and ShrineElevation.terrain_zones.has(zone))
	if zone == null:
		return
	ck.call("stairs: zone geometry matches the catalog", zone.position == stair.pos and zone.mouth == def.ramp_mouth and zone.top == def.ramp_top and zone.half_width == half and is_equal_approx(zone.height, float(def.rise)) and zone.landing.size() == 4)
	var top: Vector2 = stair.pos + (def.ramp_top as Vector2)
	var ledge_def := PlacedObjects.def_of("cliff_ledge_se")
	var run: Vector2 = ledge_def.col
	var stair_poly := PackedVector2Array()
	for q: Vector2 in zone.stair_polygon():
		stair_poly.append(stair.pos + q)
	var left_ok := false
	var right_ok := false
	var overlap := false
	var ledge_sprites := 0
	var art := stair.nodes[0] as Sprite2D
	var art_rect := Rect2(art.position + art.offset, art.texture.get_size())
	var art_in_front := zone.art.has(art)
	for o in placed.objects:
		if o.id != "cliff_ledge_se":
			continue
		left_ok = left_ok or (o.pos as Vector2) + run == top - half
		right_ok = right_ok or o.pos == top + half
		var poly := PackedVector2Array()
		for q: Vector2 in PlacedObjects.wall_collider_points(ledge_def):
			poly.append((o.pos as Vector2) + q)
		overlap = overlap or not Geometry2D.intersect_polygons(poly, stair_poly).is_empty()
		for n: Node in o.nodes:
			if n is Sprite2D:
				ledge_sprites += 1
				var s := n as Sprite2D
				if (o.pos as Vector2) + run == top - half and Rect2(s.position + s.offset, s.texture.get_size()).intersects(art_rect):
					art_in_front = art_in_front and s.z_index == art.z_index and s.position.y < art.position.y
	ck.call("stairs: left cliff face ends at the stair head", left_ok)
	ck.call("stairs: stair art draws over the left cliff face behind it", art_in_front)
	ck.call("stairs: right cliff face starts at the stair head", right_ok)
	ck.call("stairs: no cliff collider reaches onto the tread", not overlap)
	ck.call("stairs: every flanking ledge sprite is a zone occluder", ledge_sprites > 0 and zone.occluders.size() == ledge_sprites, "%d/%d" % [zone.occluders.size(), ledge_sprites])
	ck.call("stairs: both flanking ledge bodies are ramp ground bodies", zone.ground_bodies.size() == 2, str(zone.ground_bodies.size()))


## Every character climbs, not just the player: a bandit walks the map nav to the stair, up onto the landing at
## full height, and back down to the ground.
func _check_bandit_climbs(ck: Callable, arena: TrainingArena, tree: SceneTree) -> void:
	var stair: Dictionary = {}
	for o in arena.placed.objects:
		if o.id == "earth_stairs_se":
			stair = o
	if stair.is_empty():
		ck.call("bandit climb: stairs laid", false)
		return
	var zone := stair.nodes[stair.nodes.size() - 1] as CliffElevation
	var line_up := zone.to_global(zone.mouth - (zone.top - zone.mouth) * ShrineElevation.CLIMB_LEAD)
	ck.call("bandit climb: the stair line-up point is on the nav", arena.nav.is_walkable(line_up), str(line_up))
	var start := Vector2.INF
	for r: float in [220.0, 180.0, 260.0, 150.0]:
		for k in 16:
			var p: Vector2 = line_up + Vector2.from_angle(TAU * k / 16.0) * r
			if arena.nav.is_walkable(p) and is_zero_approx(ShrineElevation.target_at(p)) and start == Vector2.INF:
				start = p
	var landing_mid := Vector2.ZERO
	for q: Vector2 in zone.landing:
		landing_mid += q / float(zone.landing.size())
	var up_goal := zone.to_global(landing_mid)
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	arena.add_child(bandit)
	bandit.global_position = start
	bandit.nav = arena.nav
	bandit.set_physics_process(false)
	var reached_up := await _drive(bandit, up_goal, tree, 8.0)
	ck.call("bandit climb: reaches the cliff landing from the ground", reached_up, "at %s goal %s" % [bandit.global_position, up_goal])
	ck.call("bandit climb: stands at full cliff height up there", is_equal_approx(bandit.elevation, zone.height), str(bandit.elevation))
	ck.call("bandit climb: drawn raised by its elevation", is_equal_approx(bandit.visual.position.y, -bandit.elevation))
	var reached_down := await _drive(bandit, start, tree, 8.0)
	ck.call("bandit climb: walks back down to the ground", reached_down and is_zero_approx(bandit.elevation), "at %s e=%.1f" % [bandit.global_position, bandit.elevation])
	bandit.queue_free()


func _drive(bandit: Bandit, goal: Vector2, tree: SceneTree, seconds: float) -> bool:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var t := 0.0
	while t < seconds:
		await tree.physics_frame
		bandit._turn_pause = 0.0
		if bandit._follow(goal, bandit.move_speed, dt, 10.0, false):
			for i in 30:
				ShrineElevation.update_actor(bandit, dt)
				bandit.visual.position.y = -bandit.elevation
			return true
		bandit.move_and_slide()
		ShrineElevation.update_actor(bandit, dt)
		bandit.visual.position.y = -bandit.elevation
		t += dt
	return false


func _check_stair_links_after_reload(ck: Callable, placed: PlacedObjects) -> void:
	var zone: CliffElevation = null
	var ledges := 0
	for o in placed.objects:
		if o.id == "earth_stairs_se":
			zone = o.nodes[o.nodes.size() - 1] as CliffElevation
		elif o.id == "cliff_ledge_se":
			ledges += 1
	var live := zone != null and zone.ground_bodies.size() == 2 and zone.occluders.size() > 0
	for n in (zone.occluders if zone != null else []):
		live = live and is_instance_valid(n) and n.is_inside_tree()
	ck.call("stairs: ledge links survive a reload", ledges == 2 and live)


## Collision outside the elevation-edge layer (rails only stop actors already on the stair).
func _count_blocking(n: Node) -> int:
	if n is CollisionObject2D and (n as CollisionObject2D).collision_layer == ShrineElevation.EDGE_LAYER:
		return 0
	var c := 1 if (n is CollisionShape2D or n is CollisionPolygon2D or n is StaticBody2D) else 0
	for ch in n.get_children():
		c += _count_blocking(ch)
	return c


func _count_collision(n: Node) -> int:
	var c := 1 if (n is CollisionShape2D or n is CollisionPolygon2D or n is StaticBody2D) else 0
	for ch in n.get_children():
		c += _count_collision(ch)
	return c


func _props_inside() -> bool:
	var b := WorldScale.ARENA_BOUNDS
	for item: Array in BlightwoodMap.props():
		if not b.has_point(item[1]):
			return false
	for item: Array in BlightwoodMap.fences():
		if not b.has_point(item[1]):
			return false
	return true


func _floor_count(placed: PlacedObjects) -> int:
	var n := 0
	for o in placed.objects:
		if PlacedObjects.is_floor_tile(o.id):
			n += 1
	return n


func _distinct_floor(placed: PlacedObjects) -> int:
	var seen := {}
	for o in placed.objects:
		if PlacedObjects.is_floor_tile(o.id):
			seen[PlacedObjects.lattice_center(o.pos as Vector2)] = true
	return seen.size()
