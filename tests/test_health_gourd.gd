extends RefCounted
## Health gourd pickup: +25 HP on touch (never past max, only when hurt), respawn, random scatter, builder placement + filter.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_health_gourd_layout.json"
	placed.autosave = false
	var player := arena.get_node("Player") as PlayerController
	var tree := root.get_tree()

	ck.call("gourd art: float, glow and ember frame sets exist", HealthGourd.frames("gourd").size() >= 12 and HealthGourd.frames("glow").size() >= 1 and HealthGourd.frames("ember").size() >= 6)
	ck.call("gourd art: palette icon exists", HealthGourd.icon() != null)

	var gourds := tree.get_nodes_in_group(HealthGourd.GROUP)
	ck.call("gourd scatter: a fresh arena lies %d gourds around" % PlacedObjects.DEFAULT_GOURDS, gourds.size() == PlacedObjects.DEFAULT_GOURDS, str(gourds.size()))
	var spots_ok := true
	var spawn := (arena.get_node("Spawn") as Node2D).position
	for g: Node2D in gourds:
		spots_ok = spots_ok and arena.bounds.has_point(g.position) and g.position.distance_to(spawn) >= 260.0
		for h: Node2D in gourds:
			if h != g:
				spots_ok = spots_ok and g.position.distance_to(h.position) >= 400.0
	ck.call("gourd scatter: spots are inside the arena, off the spawn and spread apart", spots_ok)
	var tracked := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			tracked += 1
	ck.call("gourd scatter: every scattered gourd is a builder object", tracked == gourds.size())
	var a := _scatter_positions(arena, 7)
	var b := _scatter_positions(arena, 7)
	ck.call("gourd scatter: a given seed gives the same spots", a.size() == PlacedObjects.DEFAULT_GOURDS and a == b)

	# --- pickup rules (the scatter check above rebuilt the gourd nodes, so look them up again)
	await tree.process_frame
	gourds = tree.get_nodes_in_group(HealthGourd.GROUP)
	var g := gourds[0] as HealthGourd
	player.health = player.max_health
	player.global_position = g.global_position
	ck.call("gourd: full-health player cannot take one", not g.can_collect(player) and g.available)
	player.health = 40.0
	ck.call("gourd: a hurt player standing on it can", g.can_collect(player))
	player.global_position = g.global_position + (arena.bounds.get_center() - g.global_position).normalized() * 120.0  # toward the middle: stays inside the arena
	ck.call("gourd: far away it cannot be taken", not g.can_collect(player))
	player.global_position = g.global_position + Vector2(0, 15)
	await tree.process_frame
	await tree.process_frame
	ck.call("gourd: touching it heals exactly 25 and it is used up", is_equal_approx(player.health, 65.0) and not g.available, str(player.health))
	player.global_position = g.global_position
	await tree.process_frame
	ck.call("gourd: a used gourd heals nothing more", is_equal_approx(player.health, 65.0))
	player.global_position = spawn  # step off it, or the returning gourd is taken again at once
	g.respawn_left = 0.01
	await tree.create_timer(0.15).timeout
	ck.call("gourd: it comes back after its cooldown", g.available)
	player.health = 90.0
	var gained := g.collect(player)
	ck.call("gourd: healing is capped at max health (90 -> 100, +10)", player.health == player.max_health and is_equal_approx(gained, 10.0))
	player.health = player.max_health

	# --- builder
	var pos := Vector2(300, 300)
	var before := placed.objects.size()
	ck.call("gourd builder: it is in the catalog under Pickups", PlacedObjects.CATALOG.has("health_gourd") and PlacedObjects.type_of("health_gourd") == "Pickups")
	ck.call("gourd builder: can be placed on open floor", placed.can_place("health_gourd", pos))
	var obj := placed.add("health_gourd", pos, false)
	ck.call("gourd builder: placing adds a live gourd node", not obj.is_empty() and placed.objects.size() == before + 1 and obj.nodes[0] is HealthGourd and (obj.nodes[0] as HealthGourd).position == pos)
	ck.call("gourd builder: it can be picked", placed.hit_test(pos + Vector2(0, -60)) == obj)
	var solid_before := placed.obstacles().size()
	placed.add("health_gourd", pos + Vector2(500, 0), false)
	ck.call("gourd builder: pickups add no collision or nav obstacle", placed.obstacles().size() == solid_before)
	placed.move(obj, pos + Vector2(100, 0), false)
	ck.call("gourd builder: it can be moved", (obj.nodes[0] as Node2D).position == pos + Vector2(100, 0))
	var json := placed.to_dict()
	var n_saved := 0
	for it in json.items:
		if it.id == "health_gourd":
			n_saved += 1
	var total_gourds := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			total_gourds += 1
	ck.call("gourd builder: saves into the layout (version 5)", n_saved == total_gourds and int(json.version) == 5)
	placed.load_dict(json)
	var back := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			back += 1
	ck.call("gourd builder: loading the layout restores the same gourds without re-scattering", back == total_gourds and placed.loaded_version == 5, "%d vs %d" % [back, total_gourds])
	placed.remove(placed.objects[placed.objects.size() - 1], false)
	await tree.process_frame
	var left := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			left += 1
	ck.call("gourd builder: erasing removes one", left == total_gourds - 1)

	# --- filter checkbox
	var editor := arena.editor
	editor.set_open(true)
	ck.call("gourd filter: a Pickups checkbox exists", editor._filter_buttons.has("Pickups") and editor._category_sections.has("Pickups"))
	editor.set_type_filter("Pickups", false)
	ck.call("gourd filter: unchecking hides the Pickups palette section", not (editor._category_sections["Pickups"] as Control).visible)
	editor.set_type_filter("Pickups", true)
	ck.call("gourd filter: checking shows it again", (editor._category_sections["Pickups"] as Control).visible)
	ck.call("gourd filter: the palette card has the gourd picture", editor._palette_buttons.has("health_gourd") and (editor._palette_buttons["health_gourd"] as Button).icon != null)
	editor.set_open(false)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	main.queue_free()
	await tree.process_frame


## Where `scatter_gourds(seed)` puts them in a throwaway layout (does not disturb the arena's own gourds).
func _scatter_positions(arena: TrainingArena, seed_value: int) -> Array:
	var placed := arena.placed
	var mine: Array = []
	for o in placed.objects.duplicate():
		if o.id == "health_gourd":
			mine.append(o)
			placed.remove(o, false)
	placed.scatter_gourds(PlacedObjects.DEFAULT_GOURDS, seed_value)
	var out: Array = []
	for o in placed.objects:
		if o.id == "health_gourd":
			out.append(o.pos)
	for o in placed.objects.duplicate():
		if o.id == "health_gourd":
			placed.remove(o, false)
	for o in mine:
		placed.add("health_gourd", o.pos, false)
	return out
