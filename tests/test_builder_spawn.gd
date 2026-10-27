extends RefCounted
## Builder: a movable player-spawn icon, a hideable panel (map editor) and SELECT ALL / DESELECT ALL filters.

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
	placed.save_path = "user://test_builder_spawn_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	var player := tree.get_first_node_in_group("player") as PlayerController

	# --- filters
	ed.set_all_filters(false)
	var none_on := true
	for c: String in ed._filter_buttons:
		none_on = none_on and not (ed._filter_buttons[c] as CheckBox).button_pressed and not (ed._category_sections[c] as Control).visible
	ck.call("builder: DESELECT ALL clears every filter and hides every palette group", none_on)
	ed.set_all_filters(true)
	var all_on := true
	for c: String in ed._filter_buttons:
		if c != "HUD layout":
			all_on = all_on and (ed._filter_buttons[c] as CheckBox).button_pressed and (ed._category_sections[c] as Control).visible
	ck.call("builder: SELECT ALL turns every filter back on", all_on)

	# --- hide the panel; the black shell replaces the old floating tab with View-menu toggles.
	ck.call("builder: editor chrome starts shown", ed.black_shell.left_panel.visible and ed.black_shell.right_panel.visible and ed.open)
	ed.set_panel_hidden(true)
	await tree.process_frame
	ck.call("builder: HIDE collapses sidebars, editor stays open", not ed.black_shell.left_panel.visible and not ed.black_shell.right_panel.visible and ed.open)
	ed.set_panel_hidden(false)
	await tree.process_frame
	ck.call("builder: H restores both sidebars", ed.black_shell.left_panel.visible and ed.black_shell.right_panel.visible)
	ed.hide_button.pressed.emit()
	await tree.process_frame
	ck.call("builder: legacy HIDE action collapses sidebars", not ed.black_shell.left_panel.visible and not ed.black_shell.right_panel.visible)
	ed.set_panel_hidden(false)
	await tree.process_frame
	ck.call("builder: View can restore sidebars", ed.black_shell.left_panel.visible and ed.black_shell.right_panel.visible)
	# --- spawn icon
	ck.call("spawn: starts at the arena spawn", placed.spawn_point().is_equal_approx((arena.get_node("Spawn") as Node2D).position))
	var target := Vector2(600, 400)
	var o := placed.add("player_spawn", target)
	ck.call("spawn: placing the icon works", not o.is_empty() and o.nodes[0] is SpawnMarker)
	ck.call("spawn: the arena spawn and the player's respawn point follow it", (arena.get_node("Spawn") as Node2D).position.is_equal_approx(target) and player.spawn_position.is_equal_approx(target))
	var o2 := placed.add("player_spawn", target + Vector2(100, 0))
	var count := 0
	for x in placed.objects:
		if x.id == "player_spawn":
			count += 1
	ck.call("spawn: placing again moves the one icon (never two)", count == 1 and o2 == o and o.pos.is_equal_approx(target + Vector2(100, 0)))
	var hit := placed.hit_test(o.pos + Vector2(0, -60))
	ck.call("spawn: the icon can be picked up to drag", not hit.is_empty() and hit.id == "player_spawn")
	var dragged := target + Vector2(-200, 120)
	ed.selected = o
	placed.move(o, dragged, false)
	placed._changed(false)
	ck.call("spawn: dragging moves the respawn point", player.spawn_position.is_equal_approx(dragged))
	var saved := placed.to_dict()
	var in_save := false
	for it in saved.items:
		in_save = in_save or (it.id == "player_spawn" and absf(float(it.x) - dragged.x) < 0.1)
	ck.call("spawn: saved in the layout", in_save)
	placed.load_dict(saved)
	ck.call("spawn: restored on load and the player starts there", placed.spawn_point().is_equal_approx(dragged) and player.global_position.is_equal_approx(dragged))
	var obstacles_ok := true
	for ob in placed.obstacles():
		obstacles_ok = obstacles_ok and not (ob[0] as Vector2).is_equal_approx(dragged)
	ck.call("spawn: the icon is not an obstacle", obstacles_ok)
	var marker := (placed.objects.filter(func(x): return x.id == "player_spawn")[0].nodes[0]) as SpawnMarker
	SpawnMarker.shown = false
	marker._process(0.0)
	ck.call("spawn: the icon hides when the builder is closed", not marker.visible)
	SpawnMarker.shown = true
	placed.remove(placed.objects.filter(func(x): return x.id == "player_spawn")[0])
	ck.call("spawn: removing the icon restores the default spawn", placed.spawn_point().is_equal_approx(placed._default_spawn))

	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
