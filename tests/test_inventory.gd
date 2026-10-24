extends RefCounted
## D-pad inventory + Player Menu: the model (counts, stack cap, slot swaps, save), the D-pad / arrow-key inputs, eating
## gourds from a slot, the kunai throw, the touchpad-opened menu (Inventory + Jutsu tabs) and the HUD cross.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var tree := root.get_tree()

	# --- model
	var inv := PlayerInventory.new()
	inv.save_path = "user://test_inventory.json"
	ck.call("inventory: starts with 10 kunai and no gourds", inv.count_of("kunai") == 10 and inv.count_of("health_gourd") == 0 and inv.count_of("chakra_gourd") == 0)
	ck.call("inventory: default slots are up=health, right=chakra, left=kunai, down=paper tag", inv.slot_item("up") == "health_gourd" and inv.slot_item("right") == "chakra_gourd" and inv.slot_item("left") == "kunai" and inv.slot_item("down") == "paper_tag")
	ck.call("inventory: add stops at the stack cap", inv.add("health_gourd", 20) == PlayerInventory.MAX_STACK and not inv.has_room("health_gourd") and inv.add("health_gourd") == 0)
	ck.call("inventory: unknown items are refused", inv.add("banana") == 0)
	ck.call("inventory: consume takes one, and refuses at zero", inv.consume("health_gourd") and inv.count_of("health_gourd") == PlayerInventory.MAX_STACK - 1 and not inv.consume("chakra_gourd"))
	inv.assign_item("down", "kunai")
	ck.call("inventory: an item sits on one slot only (kunai moved left -> down, left takes down's old paper tag)", inv.slot_item("down") == "kunai" and inv.slot_item("left") == "paper_tag")
	inv.assign_item("up", "kunai")
	ck.call("inventory: placing an item that is on another slot swaps them", inv.slot_item("up") == "kunai" and inv.slot_item("down") == "health_gourd")
	inv.assign_jutsu("triangle", "chidori")
	ck.call("inventory: jutsu moves between R2 slots (Chidori Square -> Triangle)", inv.jutsu_slot_of("chidori") == "triangle" and inv.jutsu["square"] == "")
	ck.call("inventory: assignments save", inv.save())
	var back := PlayerInventory.new()
	back.save_path = inv.save_path
	ck.call("inventory: assignments load back, counts do not", back.load_saved() and back.slot_item("up") == "kunai" and back.jutsu_slot_of("chidori") == "triangle" and back.count_of("health_gourd") == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(inv.save_path))

	# --- inputs
	for s: String in PlayerInventory.DPAD_SLOTS:
		var has_key := false
		var has_pad := false
		for e in InputMap.action_get_events("slot_" + s):
			has_key = has_key or e is InputEventKey
			has_pad = has_pad or e is InputEventJoypadButton
		ck.call("input: slot_%s has an arrow key and a D-pad button" % s, has_key and has_pad)
	var pad_move := false
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton:
				pad_move = true
	ck.call("input: the D-pad no longer moves the player", not pad_move)
	var arrow_aim := false
	for a: String in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				arrow_aim = true
	ck.call("input: arrow keys no longer aim", not arrow_aim)
	var touch := false
	for e in InputMap.action_get_events("player_menu"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_TOUCHPAD:
			touch = true
	ck.call("input: the touchpad (large black button) opens the player menu", touch)

	# --- in the arena
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var player := arena.get_node("Player") as PlayerController
	player.inventory.save_path = "user://test_inventory_player.json"
	var bar := player.get_node("HealthBar") as HealthBar
	var menu := player.get_node("PlayerMenu") as PlayerMenu
	ck.call("player: owns an inventory and a player menu", player.inventory != null and menu != null)

	# gourds from a slot
	player.inventory.counts["health_gourd"] = 2
	player.health = 100.0
	ck.call("use: a health gourd is kept when health is already full", not player.use_slot("up") and player.inventory.count_of("health_gourd") == 2)
	player.health = 40.0
	ck.call("use: up eats a health gourd for exactly 25% of max health", player.use_slot("up") and is_equal_approx(player.health, 65.0) and player.inventory.count_of("health_gourd") == 1)
	player.inventory.counts["chakra_gourd"] = 1
	player.chakra = 10.0
	ck.call("use: right drinks a chakra gourd for 25% of max chakra", player.use_slot("right") and is_equal_approx(player.chakra, 35.0) and player.inventory.count_of("chakra_gourd") == 0)
	ck.call("use: an empty bag does nothing", not player.use_slot("right"))
	player.inventory.assign_item("down", "")
	ck.call("use: an empty slot does nothing", not player.use_slot("down"))
	player.health = player.max_health

	# kunai throw
	var kn0 := player.inventory.count_of("kunai")
	player.facing8 = Vector2.RIGHT
	ck.call("throw: left starts a throw and costs one kunai", player.use_slot("left") and player.inventory.count_of("kunai") == kn0 - 1)
	ck.call("throw: only one throw at a time", not player.use_slot("left") and player.inventory.count_of("kunai") == kn0 - 1)
	var thrown := player.kunai_thrown_count
	for i in 40:
		await tree.physics_frame
	ck.call("throw: the kunai is released mid-throw", player.kunai_thrown_count == thrown + 1)
	ck.call("throw: the throw ends", not (player._throw_t > 0.0))
	var spare := player.inventory.count_of("kunai")
	player.inventory.counts["kunai"] = 0
	ck.call("throw: no kunai, no throw", not player.use_slot("left"))
	player.inventory.counts["kunai"] = spare

	# the projectile itself
	var Dummy := GDScript.new()
	Dummy.source_code = "extends Node2D\nvar hits := 0\nfunc take_damage(a, d, k, h):\n\thits += 1\n"
	Dummy.reload()
	var dummy := Dummy.new() as Node2D
	dummy.add_to_group("enemy")
	arena.add_child(dummy)
	dummy.global_position = Vector2(300, 300)
	var k1 := PlayerKunai.spawn(arena, Vector2(200, 300), Vector2.RIGHT, player)
	for i in 30:
		k1.step(1.0 / 60.0)
		if k1.hit_result != "":
			break
	ck.call("kunai: hits an enemy in its path for light damage", k1.hit_result == "hit" and dummy.get("hits") == 1)
	dummy.global_position = Vector2(300, 900)
	var k2 := PlayerKunai.spawn(arena, Vector2(200, 300), Vector2.RIGHT, player)
	for i in 120:
		k2.step(1.0 / 60.0)
		if k2.hit_result != "":
			break
	ck.call("kunai: misses and expires at max range", k2.hit_result == "range" or k2.hit_result == "wall")
	dummy.queue_free()

	# menu
	ck.call("menu: closed at start, game running", not menu.is_open and not tree.paused)
	menu.open()
	ck.call("menu: opening pauses the game", menu.is_open and tree.paused and PlayerMenu.any_open)
	menu.switch_tab(1)
	ck.call("menu: tabs switch Inventory <-> Jutsu", menu.tab == 1)
	menu.switch_tab(1)
	ck.call("menu: tabs wrap", menu.tab == 0)
	menu.cursor = 2  # kunai
	menu.accept()
	ck.call("menu: Cross picks the highlighted item", menu.placing)
	menu.place_item_on("down")
	ck.call("menu: pressing a D-pad direction puts the item there", player.inventory.slot_item("down") == "kunai" and not menu.placing)
	menu.cursor = 4  # empty entry
	menu.accept()
	menu.place_item_on("down")
	ck.call("menu: the (empty) entry clears a slot", player.inventory.slot_item("down") == "")
	menu.cursor = 0
	menu.accept()
	menu.cancel()
	ck.call("menu: Circle drops a pick without placing it", not menu.placing and menu.is_open)
	menu.switch_tab(1)
	menu.cursor = 0  # chidori
	menu.accept()
	menu.place_jutsu_on("cross")
	ck.call("menu: Jutsu tab moves Chidori onto R2 + Cross", player.inventory.jutsu_slot_of("chidori") == "cross" and player.inventory.jutsu["square"] == "")
	menu.accept()
	menu.place_item_on("up")
	ck.call("menu: item placement is ignored on the Jutsu tab", player.inventory.slot_item("up") == "health_gourd")
	menu.cancel()
	menu.cancel()
	ck.call("menu: Circle with nothing picked closes it and resumes the game", not menu.is_open and not tree.paused and not PlayerMenu.any_open)
	ck.call("menu: closing saves the layout", FileAccess.file_exists(player.inventory.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.inventory.save_path))
	tree.paused = true
	menu.open()
	ck.call("menu: will not open over someone else's pause", not menu.is_open)
	tree.paused = false

	# HUD
	bar.layout_path = "user://test_inventory_layout.json"
	ck.call("hud: the D-pad cross is a movable HUD piece", "dpad" in HealthBar.ELEMENTS and HealthBar.ELEMENT_NAMES.has("dpad"))
	var r := bar.element_rect("dpad")
	ck.call("hud: the cross sits fully on screen", r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= 1280.0 and r.end.y <= 720.0, str(r))
	bar.set_piece_offset("dpad", Vector2(16, -16))
	ck.call("hud: the cross can be moved", bar.pos_of("dpad") == HealthBar.DPAD_ORIGIN + Vector2(16, -16))
	bar.set_piece_offset("dpad", Vector2.ZERO)

	main.queue_free()
	await tree.process_frame
