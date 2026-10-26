extends RefCounted
## Ninjas run on water at a chakra cost per second; out of chakra they slip under and are put back on dry ground.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = false
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_water_walk_layout.json"
	placed.autosave = false
	placed.load_dict({"version": 7, "items": []})
	var player := tree.get_first_node_in_group("player") as PlayerController
	var c := PlacedObjects.lattice_center(arena.bounds.get_center())
	var tile := placed.add("shore_grass_00", c, false)
	var bank := placed.add("shore_grass_03", c + Vector2(72, 0), false)
	await tree.process_frame

	ck.call("water: a full water tile counts as open water, a bank tile does not", BlightwoodWater.over_water(tree, c) and not BlightwoodWater.over_water(tree, c + Vector2(72, 0)) and not tile.is_empty() and not bank.is_empty())
	ck.call("water: the tile is a diamond, its corners outside it are dry", not BlightwoodWater.over_water(tree, c + Vector2(30, 14)))
	player.global_position = c + Vector2(100, 0)
	player._tick_water(0.1)
	var dry := player.global_position
	ck.call("water: nothing is drained on dry ground", is_equal_approx(player.chakra, player.max_chakra) and not player.over_water)
	player.global_position = c
	player._tick_water(1.0)
	ck.call("water: a second over water costs water_chakra_per_second", player.over_water and is_equal_approx(player.chakra, player.max_chakra - player.water_chakra_per_second))
	player._tick_water(0.5)
	ck.call("water: the cost is per second, not per tick", is_equal_approx(player.chakra, player.max_chakra - player.water_chakra_per_second * 1.5))

	var bridge_obj := placed.add("bridge_short_wood_u", c - Vector2(36, 18) * 1.0, false)
	await tree.process_frame
	var b := bridge_obj.nodes[0] as Bridge
	var before := player.chakra
	player.global_position = b.global_position + Vector2(36, 18) * 2.0
	player._tick_water(1.0)
	ck.call("water: a bridge deck over water is dry footing", is_equal_approx(player.chakra, before) and b.deck_contains(player.global_position))

	placed.remove(bridge_obj, false)
	await tree.process_frame
	player.global_position = c
	player.chakra = 0.0
	player.health = 100.0
	player._hit_invuln = 0.0
	player._last_dry = dry
	player._tick_water(0.1)
	ck.call("water: with no chakra the player slips under and is put back on the last dry spot, hurt", player.global_position == dry and is_equal_approx(player.health, 100.0 - PlayerController.WATER_SINK_DAMAGE) and not player.over_water)

	for o in placed.objects.duplicate():
		placed.remove(o, false)
	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
