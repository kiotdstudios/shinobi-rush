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
	ck.call("blightwood map: the bridge is laid", int(counts.get("bridge_medium_wood_u", 0)) == 1)
	ck.call("blightwood map: the waterfall is laid", int(counts.get("waterfall_small", 0)) == 1)
	ck.call("blightwood map: no old temple courtyard under the map", int(counts.get("temple_floor_corner_top", 0)) == 0)
	ck.call("blightwood map: cliff rock ground is laid", int(counts.get("shore_rock_15", 0)) >= cells.c.size() )
	ck.call("blightwood map: no two floor tiles share a cell", _floor_count(placed) == _distinct_floor(placed), str(_floor_count(placed)))
	var voids := placed.void_cells(Rect2(-1200, -600, 2400, 1200))
	ck.call("blightwood map: no white void inside the map", voids.size() == 0, str(voids.size()))
	var player := tree.get_first_node_in_group("player") as Node2D
	ck.call("blightwood map: the player starts on the courtyard", player != null and (player.global_position - spawn).length() < 120.0)
	var data := placed.to_dict()
	ck.call("blightwood map: the flag is saved", bool(data.get("blightwood_map", false)))
	var before := placed.objects.size()
	placed.load_dict(data)
	BlightwoodMap.enabled = true
	BlightwoodMap.populate(arena)
	BlightwoodMap.enabled = false
	var braziers := 0
	for o in placed.objects:
		if o.id == "blight_stone_brazier":
			braziers += 1
	ck.call("blightwood map: reload does not lay it again", braziers == 3 and absi(placed.objects.size() - before) <= 2, "%d vs %d" % [placed.objects.size(), before])
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
