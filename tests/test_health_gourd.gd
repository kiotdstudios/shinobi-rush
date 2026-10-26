extends RefCounted
## Health/chakra gourd pickup: collected into the held-items inventory on touch (owner 2026-10-25;
## was an instant +25% heal, only while hurt), respawn, random scatter, builder placement + filter.

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
	# Owner 2026-10-25: collecting now stocks the inventory instead of healing on touch, so the old
	# "only when hurt" gate is gone -- a full-health player can (and must be able to) still collect.
	await tree.process_frame
	gourds = tree.get_nodes_in_group(HealthGourd.GROUP)
	var g := gourds[0] as HealthGourd
	player.health = player.max_health
	player.global_position = g.global_position
	ck.call("gourd: a full-health player CAN still take one (inventory, not an instant heal)", g.can_collect(player) and g.available)
	player.global_position = g.global_position + (arena.bounds.get_center() - g.global_position).normalized() * 120.0  # toward the middle: stays inside the arena
	ck.call("gourd: far away it cannot be taken", not g.can_collect(player))
	player.global_position = g.global_position + Vector2(0, 15)
	await tree.process_frame
	await tree.process_frame
	ck.call("gourd: touching it adds one to the inventory, leaves HP untouched, and is used up", player.held_items.count("health_gourd") == 1 and is_equal_approx(player.health, player.max_health) and not g.available)
	player.global_position = g.global_position
	await tree.process_frame
	ck.call("gourd: a used gourd grants nothing more while unavailable", player.held_items.count("health_gourd") == 1)
	player.global_position = spawn  # step off it, or the returning gourd is taken again at once
	g.respawn_left = 0.01
	await tree.create_timer(0.15).timeout
	ck.call("gourd: it comes back after its cooldown", g.available)
	var gained := g.collect(player)
	ck.call("gourd: a second collection stacks another one, still no HP change", player.held_items.count("health_gourd") == 2 and is_equal_approx(gained, 1.0))
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
	ck.call("gourd builder: saves into the layout (current version)", n_saved == total_gourds and int(json.version) == PlacedObjects.SAVE_VERSION)
	placed.load_dict(json)
	var back := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			back += 1
	ck.call("gourd builder: loading the layout restores the same gourds without re-scattering", back == total_gourds and placed.loaded_version == PlacedObjects.SAVE_VERSION, "%d vs %d" % [back, total_gourds])
	placed.remove(placed.objects[placed.objects.size() - 1], false)
	await tree.process_frame
	var left := 0
	for o in placed.objects:
		if o.id == "health_gourd":
			left += 1
	ck.call("gourd builder: erasing removes one", left == total_gourds - 1)

	# --- chakra gourd
	ck.call("chakra gourd art: float, glow and ember frames exist", HealthGourd.frames("gourd", "chakra").size() >= 12 and HealthGourd.frames("glow", "chakra").size() >= 1 and HealthGourd.frames("ember", "chakra").size() >= 6)
	var blues := tree.get_nodes_in_group(HealthGourd.CHAKRA_GROUP)
	ck.call("chakra gourd scatter: a fresh arena lies %d chakra gourds around (health ones unchanged at %d)" % [PlacedObjects.DEFAULT_CHAKRA_GOURDS, PlacedObjects.DEFAULT_GOURDS], blues.size() == PlacedObjects.DEFAULT_CHAKRA_GOURDS and tree.get_nodes_in_group(HealthGourd.GROUP).size() >= PlacedObjects.DEFAULT_GOURDS, str(blues.size()))
	var cg := blues[0] as HealthGourd
	cg.available = true
	player.health = 40.0
	player.chakra = player.max_chakra
	player.global_position = cg.global_position
	ck.call("chakra gourd: a full-chakra player CAN still take one (inventory, not an instant restore)", cg.can_collect(player))
	var hp_before := player.health
	var got := cg.collect(player)
	ck.call("chakra gourd: adds one to the chakra-gourd slot, touches neither stat", player.held_items.count("chakra_gourd") == 1 and is_equal_approx(got, 1.0) and player.health == hp_before and player.chakra == player.max_chakra and not cg.available)
	cg.available = true
	var got2 := cg.collect(player)
	ck.call("chakra gourd: a second collection stacks another one", player.held_items.count("chakra_gourd") == 2 and is_equal_approx(got2, 1.0))
	player.health = 60.0
	var hg := tree.get_nodes_in_group(HealthGourd.GROUP)[0] as HealthGourd
	var h_got := hg.collect(player)
	ck.call("health gourd: adds to its OWN slot and leaves chakra alone", player.held_items.count("health_gourd") >= 1 and is_equal_approx(h_got, 1.0) and player.chakra == player.max_chakra)
	player.health = player.max_health
	ck.call("chakra gourd builder: in the catalog under Pickups", PlacedObjects.CATALOG.has("chakra_gourd") and PlacedObjects.type_of("chakra_gourd") == "Pickups")
	var cobj := placed.add("chakra_gourd", Vector2(-300, 400), false)
	ck.call("chakra gourd builder: placing makes a chakra-kind gourd", not cobj.is_empty() and (cobj.nodes[0] as HealthGourd).kind == "chakra")
	var cjson := placed.to_dict()
	placed.load_dict(cjson)
	await tree.process_frame
	var chakra_back := 0
	for o in placed.objects:
		if o.id == "chakra_gourd":
			chakra_back += 1
	ck.call("chakra gourd builder: saved and reloaded as chakra gourds", chakra_back >= 1 and tree.get_nodes_in_group(HealthGourd.CHAKRA_GROUP).size() == chakra_back)
	var old := {"version": 5, "items": [{"id": "health_gourd", "x": 200.0, "y": 300.0}]}
	placed.load_dict(old)
	await tree.process_frame
	ck.call("chakra gourd: a v5 layout reports it needs the chakra scatter", placed.loaded_version == 5 and tree.get_nodes_in_group(HealthGourd.CHAKRA_GROUP).is_empty())
	placed.scatter_defaults(true)
	await tree.process_frame
	ck.call("chakra gourd: chakra-only scatter adds just chakra gourds beside the saved health one", tree.get_nodes_in_group(HealthGourd.CHAKRA_GROUP).size() == PlacedObjects.DEFAULT_CHAKRA_GOURDS and placed.loaded_version == PlacedObjects.SAVE_VERSION)

	# --- filter checkbox
	var editor := arena.editor
	editor.set_open(true)
	ck.call("gourd filter: a Pickups checkbox exists", editor._filter_buttons.has("Pickups") and editor._category_sections.has("Pickups"))
	editor.set_type_filter("Pickups", false)
	ck.call("gourd filter: unchecking hides the Pickups palette section", not (editor._category_sections["Pickups"] as Control).visible)
	editor.set_type_filter("Pickups", true)
	ck.call("gourd filter: checking shows it again", (editor._category_sections["Pickups"] as Control).visible)
	ck.call("gourd filter: the palette card has the gourd picture", editor._palette_buttons.has("health_gourd") and (editor._palette_buttons["health_gourd"] as Button).icon != null and editor._palette_buttons.has("chakra_gourd") and (editor._palette_buttons["chakra_gourd"] as Button).icon != null)
	editor.set_open(false)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	main.queue_free()
	await tree.process_frame


## Where `scatter_gourds(seed)` puts them in a throwaway layout (does not disturb the arena's own gourds).
func _scatter_positions(arena: TrainingArena, seed_value: int) -> Array:
	var placed := arena.placed
	var mine: Array = []
	for o in placed.objects.duplicate():
		if o.id in ["health_gourd", "chakra_gourd"]:
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
		placed.add(o.id, o.pos, false)
	return out
