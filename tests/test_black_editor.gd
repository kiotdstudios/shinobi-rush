extends RefCounted
## The black shell adapts, rather than replaces, WorldEditor actions and layout storage.

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
	var ed := arena.editor as WorldEditor
	var placed := arena.placed as PlacedObjects
	placed.autosave = false
	var shell := ed.black_shell
	ck.call("black editor: shell mounted without replacing model", shell != null and shell.editor == ed and ed.placed == placed)
	ck.call("black editor: world canvas takes input", shell.center.mouse_filter == Control.MOUSE_FILTER_IGNORE and shell.canvas_rect().size.x > 0.0, str(shell.canvas_rect()) + " / shell=" + str(shell.get_global_rect()))
	ck.call("black editor: chrome consumes input", shell.left_panel.mouse_filter == Control.MOUSE_FILTER_STOP and shell.right_panel.mouse_filter == Control.MOUSE_FILTER_STOP)
	ck.call("black editor: no empty duplicate Layers section", shell.right_content.find_child("LayerContent", false, false) == null)
	ck.call("black editor: no duplicate legacy Layers rows", ed._layer_buttons.is_empty())
	# A release swallowed by chrome must not leave either pan gesture active.
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	ed._panning = true
	ed._input(release)
	ck.call("black editor: outside release cancels pan", not ed._panning)
	ed._stroke = true
	ed._stroke_changed = false
	ed._input(release)
	ck.call("black editor: outside release ends paint stroke", not ed._stroke)
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = false
	ed._middle_pan = true
	ed._middle_pan_moved = true
	ed._input(middle)
	ck.call("black editor: outside middle release cancels pan", not ed._middle_pan)
	var sample := placed.add("ground9_center", Vector2(1656, 720))
	ed.set_tool("select")
	ed._middle_pan = true
	ed._middle_pan_moved = false
	ed._middle_pan_world = Vector2(1656, 720)
	ed._input(middle)
	ck.call("black editor: middle click eyedrops a floor tile", ed.tool == "paint" and ed.place_id == "ground9_center")
	placed.remove(sample)
	placed.set_type_locked("Ground / paths", true)
	ck.call("black editor: old category lock allows new path placement", not placed.editor_layer_locked("ground9_center") and placed.can_place("ground9_center", Vector2(1656, 720)))
	placed.set_type_locked("Ground / paths", false)
	placed.set_type_visible("Ground / paths", false)
	ck.call("black editor: legacy visibility filter remains view-only for placement", placed.can_place("ground9_center", Vector2(1656, 720)))
	placed.set_type_visible("Ground / paths", true)
	shell.show_page(false)
	await tree.process_frame
	ck.call("black editor: settings hides asset browser", ed.settings_page.get_parent().visible and not ed.black_assets.visible)
	shell.show_page(true)
	await tree.process_frame
	ck.call("black editor: assets return after settings", ed.black_assets.is_visible_in_tree() and not ed.settings_page.get_parent().visible)
	for toggle_id: int in [shell.VIEW_COLLISION, shell.VIEW_LIGHTING, shell.VIEW_NAVIGATION]:
		shell._on_view_id(toggle_id)
	ck.call("black editor: View controls enable real overlays", ed.show_collision_overlay and ed.show_lighting_overlay and ed.show_navigation_overlay)
	for toggle_id: int in [shell.VIEW_COLLISION, shell.VIEW_LIGHTING, shell.VIEW_NAVIGATION]:
		shell._on_view_id(toggle_id)
	ck.call("black editor: View controls disable overlays", not ed.show_collision_overlay and not ed.show_lighting_overlay and not ed.show_navigation_overlay)
	ed.set_tool("paint", "temple_floor_center")
	ed.random_variation = true
	var variation_cell := Vector2(1656, 720)
	ed._apply_cells([variation_cell])
	var variation_tiles := placed.floor_tiles_in_cell(variation_cell)
	var variation_id := str(variation_tiles.back().id) if not variation_tiles.is_empty() else ""
	ck.call("black editor: random variation is stable across repeat brush", variation_id != "" and not ed._apply_cells([variation_cell]) and str(placed.floor_tiles_in_cell(variation_cell).back().id) == variation_id)
	ed.random_variation = false
	ck.call("black editor: Rules exposes the original void controls", (func() -> bool:
		ed.black_assets.set_tab("Rules")
		var row: Control = ed.black_assets.rules_page.find_child("VoidControls", false, false)
		var ok := row != null and row.get_parent() == ed.black_assets.rules_page and row.is_visible_in_tree() and ed.fill_void_button.get_parent() == row and ed.next_void_button.get_parent() == row and ed.fill_void_button.pressed.is_connected(ed.fill_void)
		ed.black_assets.set_tab("Tiles")
		return ok).call())
	ck.call("black editor: legacy controls remain accessible", ed.build_page != null and ed.settings_page != null and shell.legacy_build_scroll != null)
	ck.call("black editor: valid JSON import roundtrips exact items", (func() -> bool:
		var before := placed.to_dict()
		return shell.open_layout_text(JSON.stringify(before), "test") and placed.to_dict().items == before.items).call())
	ck.call("black editor: malformed import leaves world untouched", (func() -> bool:
		var n := placed.objects.size()
		return not shell.open_layout_text("{broken") and placed.objects.size() == n).call())
	ck.call("black editor: browser contains all catalog assets", (func() -> bool:
		for cat: Array in PlacedObjects.CATEGORIES:
			for id: String in cat[1]:
				if not ed.black_assets.cards.has(id):
					return false
		return true).call())
	var spot := Vector2(1656, 720)
	var obj := placed.add("ground9_center", spot)
	ck.call("black editor: can add test floor", not obj.is_empty())
	var mini := ed.black_minimap
	var map_point := mini.map_to_world(mini.world_to_map(spot))
	ck.call("black editor: minimap maps world coordinates correctly", map_point.distance_to(spot) < 1.0)
	var cam := ed._camera()
	var offset_before := cam.offset if cam != null else Vector2.ZERO
	ck.call("black editor: minimap navigates the live camera", mini.navigate_to(spot) and cam != null and cam.offset.distance_to(offset_before) > 1.0)
	ed.selected = obj
	ed.black_inspector.update_state()
	ed.black_inspector._x.value = spot.x + 36
	ck.call("black editor: inspector commits one movement", ed.black_inspector.commit_position() and obj.pos.x == spot.x + 36)
	ck.call("black editor: legacy floating inspector stays hidden", not ed.inspector.visible)
	ck.call("black editor: inspector move is undoable", placed.undo() and placed.objects.any(func(o): return o.id == "ground9_center" and o.pos == spot))
	ed.selected = {}
	ed.black_inspector.set_layer_locked("Paths", true)
	ck.call("black editor: locked layer rejects paint", placed.type_locked("ground9_center") and not placed.paint_cell("ground9_center", spot + Vector2(72, 0)))
	ed.black_inspector.set_layer_locked("Paths", false)
	var before_hide: Array = placed.to_dict().items
	ed.black_inspector.set_layer_visible("Paths", false)
	ck.call("black editor: hidden layer does not change save model", not placed.type_visible("ground9_center") and placed.to_dict().items == before_hide)
	ck.call("black editor: hidden paths cannot be painted or placed", not placed.paint_cell("ground9_center", spot) and not placed.can_place("ground9_center", spot))
	ck.call("black editor: hidden paths cannot be replaced by visible grass", not placed.paint_cell("grass9_center", spot))
	ck.call("black editor: terrain CLEAR cannot erase hidden paths", not AutoTile.new(placed).apply([spot], ""))
	# Group drag must not overwrite a floor tile hidden by the grouped editor layer.
	var moving := placed.add("grass9_center", spot + Vector2(72, 0))
	ed.selection = [moving]
	ed.selected = {}
	ed._group_from = [moving.pos]
	ed._group_dragging = true
	placed.move(moving, spot, false)
	ed.end_group_drag()
	ck.call("black editor: group drag cannot overwrite hidden floor", placed.objects.has(obj) and moving.pos == spot + Vector2(72, 0))
	placed.remove(moving)
	ed.selection = []
	ed.black_inspector.set_layer_visible("Paths", true)
	placed.remove(obj)
	shell.set_left_open(false)
	shell.set_right_open(false)
	await tree.process_frame
	ck.call("black editor: both sidebars collapse and canvas remains editable", shell.canvas_rect().size.x > 0.0 and ed.open and not shell.left_panel.visible and not shell.right_panel.visible, str(shell.canvas_rect()))
	ck.call("black editor: H state follows View collapse", ed.panel_hidden)
	shell.set_left_open(true)
	shell.set_right_open(true)
	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
