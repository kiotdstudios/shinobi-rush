extends RefCounted
## The Shinobi Rush Map Editor page: undo / redo, fill void, next void, the BUILD | SETTINGS tabs, the pinned SAVE row and the
## no-playtest rule (all on the same build, switched on by MapEditorMode).

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
	placed.save_path = "user://test_map_editor_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false

	ck.call("map editor: mode is active and the builder opens up front", ed.map_mode and ed.open)
	ck.call("map editor: BUILD and SETTINGS tabs exist", ed.tab_build_button != null and ed.tab_settings_button != null and ed.build_page != null and ed.settings_page != null)
	ck.call("map editor: title says Map Editor", "MAP EDITOR" in ed.title_label.text)
	ed.set_open(false)
	ck.call("map editor: there is no playtest and the editor cannot be closed (only the panel hides)", ed.open and ed.panel.visible and not ed.tab.visible)
	var vp := root.get_viewport().get_visible_rect()
	ck.call("map editor: the panel fits on screen", vp.encloses(ed.panel.get_global_rect().grow(-1.0)), str(ed.panel.get_global_rect()) + " in " + str(vp))
	ck.call("map editor: SAVE is visible on screen", ed.save_button.is_visible_in_tree() and vp.encloses(ed.save_button.get_global_rect().grow(-1.0)), str(ed.save_button.get_global_rect()) + " in " + str(vp))
	ck.call("map editor: SAVE sits inside the panel", ed.panel.get_global_rect().encloses(ed.save_button.get_global_rect().grow(-1.0)))
	ck.call("map editor: the palette keeps a usable height", ed.palette_scroll.get_global_rect().size.y >= 100.0, str(ed.palette_scroll.get_global_rect().size.y))
	ck.call("map editor: the filters start collapsed", not (ed._ui["filters"] as Control).visible)
	var plr := root.get_tree().get_first_node_in_group("player") as Node
	ck.call("map editor: the player is frozen and hidden", plr != null and plr.process_mode == Node.PROCESS_MODE_DISABLED and not (plr as CanvasItem).visible)
	ck.call("map editor: the player HUD is gone", ed.hud_bar() != null and not ed.hud_bar().visible)
	ck.call("map editor: the enemies are frozen and hidden", (func() -> bool:
		for c in arena.get_children():
			if c is Bandit and (c.process_mode != Node.PROCESS_MODE_DISABLED or (c as CanvasItem).visible):
				return false
		return true).call())
	ed._show_page(false)
	ck.call("map editor: SETTINGS tab shows the settings page", ed.settings_page.get_parent().visible and not ed.build_page.visible)
	ed._show_page(true)
	ck.call("map editor: BUILD tab shows the palette", ed.build_page.visible and not ed.settings_page.get_parent().visible)
	for i in 3:
		await tree.process_frame
	var sp := SettingsPanel.instance()
	if sp != null:
		ck.call("map editor: settings rows live in the SETTINGS tab", sp.rows != null and sp.rows.get_parent() == ed.settings_page)
		ck.call("map editor: the bottom Settings popup is hidden", not sp.tab.visible and not sp.panel.visible)

	# undo / redo
	placed.clear_history()
	var spot := Vector2(1008, 540)
	var start := placed.objects.size()
	var o := placed.add("ground9_center", spot)
	ck.call("undo: a placement adds one object", not o.is_empty() and placed.objects.size() == start + 1 and placed.can_undo())
	ck.call("undo: undo removes it", placed.undo() and placed.objects.size() == start and placed.floor_tiles_in_cell(spot).is_empty())
	ck.call("undo: redo puts it back", placed.redo() and placed.objects.size() == start + 1 and placed.floor_tiles_in_cell(spot).size() == 1)
	var tile: Dictionary = placed.floor_tiles_in_cell(spot)[0]
	placed.move(tile, spot + Vector2(72, 0))
	ck.call("undo: a move is undone", placed.undo() and placed.floor_tiles_in_cell(spot).size() == 1 and placed.floor_tiles_in_cell(spot + Vector2(72, 0)).is_empty())
	placed.remove(placed.floor_tiles_in_cell(spot)[0])
	ck.call("undo: a delete is undone", placed.undo() and placed.floor_tiles_in_cell(spot).size() == 1)
	placed.paint_cell("grass9_center", spot)
	placed._changed(false)
	ck.call("undo: a paint-over (remove + add) is ONE step", placed.undo() and placed.floor_tiles_in_cell(spot).size() == 1 and placed.floor_tiles_in_cell(spot)[0].id == "ground9_center")
	ck.call("undo: a new action clears redo", placed.redo() and (placed.add("ground9_center", spot + Vector2(144, 0)).size() > 0) and not placed.can_redo())
	ck.call("undo: nothing to undo reports false", (func() -> bool:
		placed.clear_history()
		return not placed.undo()).call())
	ed.undo()
	ck.call("undo: the editor button path says nothing to undo", "Nothing to undo" in ed.status.text)

	# void: edge cells must be fillable, otherwise save would be blocked forever
	var all_void := placed.void_cells(arena.bounds)
	var fillable := true
	for c: Vector2 in all_void:
		if not arena.bounds.encloses(Rect2(c - Vector2(36, 18), Vector2(72, 36))):
			fillable = false
			break
	ck.call("void: every reported void cell can actually be painted", fillable and all_void.size() > 0)
	placed.clear_history()
	ed.place_id = "ground9_center"
	ed.fill_void()
	ck.call("fill void: nothing is left white", placed.void_cells(arena.bounds).is_empty(), str(placed.void_cells(arena.bounds).size()))
	ck.call("fill void: a filled level passes the save checker", (func() -> bool:
		ed.void_check = true
		var ok := ed.save_now()
		ed.void_check = false
		return ok).call())
	ck.call("fill void: the whole fill is one undo step", placed.undo() and placed.void_cells(arena.bounds).size() == all_void.size(), str(placed.void_cells(arena.bounds).size()) + " vs " + str(all_void.size()))
	ed.jump_to_next_void()
	ck.call("next void: the view lands on a void cell", ed.void_focus != Vector2.INF and placed.void_cells(arena.bounds).has(ed.void_focus))
	var first := ed.void_focus
	ed.jump_to_next_void()
	ck.call("next void: pressing again moves to a different cell", ed.void_focus != first)

	# build only
	ed.set_open(false)
	ck.call("build only: the editor cannot be closed into a playable level", ed.open and ed.panel.visible)
	var f5 := InputEventKey.new()
	f5.keycode = KEY_F5
	f5.pressed = true
	ed._unhandled_input(f5)
	ck.call("build only: F5 does nothing", ed.open)

	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
