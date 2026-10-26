extends RefCounted
## Held items / D-pad quick-use slots (owner 2026-10-25: "10x kunai, health gourd, chakra gourd, and
## paper tags ... d pad is used to use these items"). Covers: HeldItems data model, the four
## use_item_N input actions + inventory_toggle actually existing in the InputMap, PlayerController.
## use_item_slot for each of the four items, BanditKunai's new hit_group fallback (player throws with
## no single locked target), and PaperTag's flight -> armed -> explode lifecycle.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	_test_data_model()
	_test_input_map()
	await _test_use_item_slots(root)
	await _test_bandit_kunai_hit_group(root)
	_test_paper_tag_lifecycle()


func _test_data_model() -> void:
	var items := HeldItems.new()
	ck.call("held items: starting loadout is 10 kunai, 0 of everything else", items.count("kunai") == 10 and items.count("health_gourd") == 0 and items.count("chakra_gourd") == 0 and items.count("paper_tag") == 0)
	ck.call("held items: default D-pad order is kunai/health/chakra/paper_tag (up/right/down/left)", items.order == ["kunai", "health_gourd", "chakra_gourd", "paper_tag"])
	ck.call("held items: spend() consumes one and returns true", items.spend("kunai") and items.count("kunai") == 9)
	items.counts["paper_tag"] = 0
	ck.call("held items: spend() on an empty stack returns false and changes nothing", not items.spend("paper_tag") and items.count("paper_tag") == 0)
	items.add("paper_tag", 3)
	ck.call("held items: add() grants the requested amount", items.count("paper_tag") == 3)
	ck.call("held items: drop() discards up to what is held and returns the amount actually dropped", items.drop("paper_tag", 2) == 2 and items.count("paper_tag") == 1 and items.drop("paper_tag", 5) == 1 and items.count("paper_tag") == 0)
	items.swap_slots(0, 3)
	ck.call("held items: swap_slots exchanges two D-pad directions (ids, not counts)", items.order == ["paper_tag", "health_gourd", "chakra_gourd", "kunai"] and items.count("kunai") == 9)
	items.swap_slots(0, 0)
	ck.call("held items: swapping a slot with itself is a no-op", items.order == ["paper_tag", "health_gourd", "chakra_gourd", "kunai"])


func _test_input_map() -> void:
	for action in ["use_item_1", "use_item_2", "use_item_3", "use_item_4", "inventory_toggle"]:
		ck.call("input map: \"%s\" exists" % action, InputMap.has_action(action))
	ck.call("input map: inventory_toggle is bound to the PS4 touchpad (JOY_BUTTON_TOUCHPAD = 20), the \"black pad\"", InputMap.action_get_events("inventory_toggle").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_TOUCHPAD))
	var dpad_buttons := {11: false, 12: false, 13: false, 14: false}
	for action in ["use_item_1", "use_item_2", "use_item_3", "use_item_4"]:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				dpad_buttons[(e as InputEventJoypadButton).button_index] = true
	ck.call("input map: all four D-pad buttons (11-14) are claimed by a use_item_N action", dpad_buttons.values().all(func(v: bool) -> bool: return v))
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		var has_dpad_button := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
		ck.call("input map: \"%s\" no longer carries a redundant D-pad button event (freed for items; the stick axis event still does the job)" % action, not has_dpad_button)


func _spawn_player(root: Node) -> Dictionary:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var player := arena.get_node("Player") as PlayerController
	return {"main": main, "arena": arena, "player": player}


func _test_use_item_slots(root: Node) -> void:
	var s := await _spawn_player(root)
	var main: Node = s.main
	var player: PlayerController = s.player
	var arena: TrainingArena = s.arena

	# Slot 0 (UP) = kunai: spends ammo and throws a shared BanditKunai aimed at the player's facing,
	# targeting the "enemy" group generically (no single locked target -- see hit_group).
	player.facing8 = Vector2.RIGHT
	var kunai_before := player.held_items.count("kunai")
	player.use_item_slot(0)
	await root.get_tree().process_frame
	var thrown := arena.get_node_or_null("BanditKunai")
	ck.call("use item: kunai slot spends one kunai and throws it with hit_group=\"enemy\"", player.held_items.count("kunai") == kunai_before - 1 and thrown != null and (thrown as BanditKunai).hit_group == "enemy" and (thrown as BanditKunai).target == null)
	if thrown != null:
		(thrown as Node).queue_free()
		await root.get_tree().process_frame  # queue_free() defers removal -- let it actually leave before checking "no BanditKunai" below

	player.held_items.counts["kunai"] = 0
	var hp_after_empty := player.held_items.count("kunai")
	player.use_item_slot(0)
	ck.call("use item: an empty slot throws/uses nothing (spend() fails closed)", player.held_items.count("kunai") == hp_after_empty and arena.get_node_or_null("BanditKunai") == null)

	# Slot 1 (RIGHT) = health gourd: heals from the inventory, not from a world pickup.
	player.held_items.add("health_gourd", 1)
	player.health = 50.0
	player.use_item_slot(1)
	ck.call("use item: health gourd slot heals 25% of max HP and spends the stack", is_equal_approx(player.health, 75.0) and player.held_items.count("health_gourd") == 0)

	# Slot 2 (DOWN) = chakra gourd.
	player.held_items.add("chakra_gourd", 1)
	player.chakra = 50.0
	player.use_item_slot(2)
	ck.call("use item: chakra gourd slot restores 25% of max chakra and spends the stack", is_equal_approx(player.chakra, 75.0) and player.held_items.count("chakra_gourd") == 0)

	# Slot 3 (LEFT) = paper tag: spends one and spawns a PaperTag headed along facing8.
	player.held_items.add("paper_tag", 1)
	player.facing8 = Vector2.DOWN
	player.use_item_slot(3)
	await root.get_tree().process_frame
	var tag := arena.get_node_or_null("PaperTag")
	ck.call("use item: paper tag slot spends one and spawns a PaperTag flying along facing8", player.held_items.count("paper_tag") == 0 and tag != null and (tag as PaperTag).dir.is_equal_approx(Vector2.DOWN))
	if tag != null:
		(tag as Node).queue_free()

	# Rearranging actually changes which physical slot does what.
	player.held_items.swap_slots(0, 1)  # UP now holds what RIGHT used to (health_gourd), RIGHT now holds kunai
	player.held_items.add("health_gourd", 1)
	player.health = 10.0
	player.use_item_slot(0)
	ck.call("use item: after swap_slots, pressing the UP slot now uses the REARRANGED item (health gourd)", is_equal_approx(player.health, 35.0))

	main.queue_free()
	await root.get_tree().process_frame


class _KunaiTestDummy extends Node2D:
	var hits: int = 0
	func take_hit(_amount: float, _dir: Vector2, _kb: float, _who) -> bool:
		hits += 1
		return true


func _test_bandit_kunai_hit_group(root: Node) -> void:
	var s := await _spawn_player(root)
	var main: Node = s.main
	var arena: TrainingArena = s.arena
	var player: PlayerController = s.player
	# A private group, NOT "enemy": the arena's own real bandit is also in "enemy" and could be
	# closer than this dummy depending on where it happens to be standing, which would make
	# _resolve_victim() pick IT instead and the test flaky. hit_group is just a group name -- any
	# name works, so prove the mechanism with one that cannot collide with real content.
	const TEST_GROUP := "__kunai_hit_group_test__"

	var dummy := _KunaiTestDummy.new()
	dummy.name = "KunaiHitGroupDummy"
	dummy.add_to_group(TEST_GROUP)
	arena.add_child(dummy)
	dummy.global_position = player.global_position + Vector2(200, 0)

	var kn := BanditKunai.spawn(arena, player.global_position, Vector2.RIGHT, player, null)
	kn.hit_group = TEST_GROUP
	var picked := kn._resolve_victim()
	ck.call("bandit kunai: with target=null and hit_group set, _resolve_victim() finds the dummy in that group, not a fixed `target`", picked == dummy and kn.target == null)
	for i in 60:  # step until it reaches the dummy's HIT_RADIUS
		kn.step(1.0 / 60.0)
		if kn.hit_result != "":
			break
	ck.call("bandit kunai: a hit_group throw actually lands on a real node in that group (player's generic throw, not a bandit's locked throw)", dummy.hits == 1 and kn.hit_result == "hit")

	dummy.queue_free()
	main.queue_free()
	await root.get_tree().process_frame


func _test_paper_tag_lifecycle() -> void:
	var tag := PaperTag.new()
	tag.dir = Vector2.RIGHT
	tag.hit_group = "__paper_tag_test_group__"
	ck.call("paper tag: starts in flight", tag.state == "flying")
	# Flies without a tree (no wall-raycast possible outside one; step() guards is_inside_tree()).
	# FLIGHT_SPEED 420 px/s, FLIGHT_RANGE 420 px -> exactly 60 steps at 60fps; a few extra for margin.
	for i in 65:
		tag.step(1.0 / 60.0)
	ck.call("paper tag: arms after travelling its full flight range", tag.state == "armed")
	for i in 70:  # > FUSE_SECONDS at 60fps
		tag.step(1.0 / 60.0)
	ck.call("paper tag: detonates on its own after the fuse runs out", tag.state == "done")
	ck.call("paper tag: an explosion with nobody in the blast group hits nobody", tag.hit_count == 0)
	tag.free()  # never entered a tree (deliberately, to test step() without is_inside_tree()) -- queue_free() would never run
