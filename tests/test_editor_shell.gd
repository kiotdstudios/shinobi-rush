extends RefCounted
## The all-black Map Editor chrome (EditorShell): toolbar, sidebars, status bar. Every control must drive the real editor.

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
	placed.save_path = "user://test_editor_shell_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	var sh := ed.shell

	ck.call("shell: the map editor builds the black shell", sh != null and sh.is_inside_tree())
	ck.call("shell: palette is black / white, no orange", WorldEditor.ACCENT.r > 0.9 and WorldEditor.ACCENT.g > 0.9 and WorldEditor.ACCENT.b > 0.9 and WorldEditor.BG == Color("#101010"))
	ck.call("shell: the old panel lives inside the left sidebar", ed.panel.get_parent() == sh.left)
	ck.call("shell: sidebars and bars swallow mouse input, the shell itself does not", sh.mouse_filter == Control.MOUSE_FILTER_IGNORE and sh.left.mouse_filter == Control.MOUSE_FILTER_STOP and sh.right.mouse_filter == Control.MOUSE_FILTER_STOP and sh.toolbar.mouse_filter == Control.MOUSE_FILTER_STOP and sh.status_bar.mouse_filter == Control.MOUSE_FILTER_STOP)
	var vp := root.get_viewport().get_visible_rect()
	ck.call("shell: toolbar, sidebars and status bar sit inside the window", vp.encloses(sh.toolbar.get_global_rect().grow(-1.0)) and vp.encloses(sh.left.get_global_rect().grow(-1.0)) and vp.encloses(sh.right.get_global_rect().grow(-1.0)) and vp.encloses(sh.status_bar.get_global_rect().grow(-1.0)), "%s | %s %s %s %s" % [vp, sh.toolbar.get_global_rect(), sh.left.get_global_rect(), sh.right.get_global_rect(), sh.status_bar.get_global_rect()])
	ck.call("shell: the canvas keeps most of the width", sh.canvas_rect().size.x > vp.size.x * 0.4, str(sh.canvas_rect()))

	# undo / redo buttons mirror the real history
	placed.clear_history()
	await tree.process_frame
	ck.call("toolbar: undo and redo start disabled with no history", sh.btn_undo.disabled and sh.btn_redo.disabled)
	var spot := Vector2(1008, 540)
	var start := placed.objects.size()
	placed.add("ground9_center", spot)
	await tree.process_frame
	ck.call("toolbar: undo enables after an edit", not sh.btn_undo.disabled and sh.btn_redo.disabled)
	sh.btn_undo.pressed.emit()
	ck.call("toolbar: the Undo button undoes the edit", placed.objects.size() == start)
	await tree.process_frame
	ck.call("toolbar: redo enables after undo", not sh.btn_redo.disabled)
	sh.btn_redo.pressed.emit()
	ck.call("toolbar: the Redo button redoes it", placed.objects.size() == start + 1)

	# save
	if FileAccess.file_exists(placed.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	sh.btn_save.pressed.emit()
	ck.call("toolbar: Save writes the layout file", FileAccess.file_exists(placed.save_path))

	# grid + snap
	ed.show_grid = false
	sh.btn_grid.button_pressed = true
	ck.call("toolbar: Grid toggles the floor grid", ed.show_grid)
	ed.show_grid = false
	await tree.process_frame
	ck.call("toolbar: Grid button follows the editor state", not sh.btn_grid.button_pressed)
	ed.snap = 30
	await tree.process_frame
	ck.call("toolbar: Snapping shows on", sh.btn_snap.button_pressed)
	sh.btn_snap.button_pressed = false
	ck.call("toolbar: Snapping off sets snap to 0", ed.snap == 0)
	sh.btn_snap.button_pressed = true
	ck.call("toolbar: Snapping on restores a grid size", ed.snap == 30)

	# New needs two clicks
	var n := placed.objects.size()
	sh.btn_new.pressed.emit()
	ck.call("toolbar: New asks first", placed.objects.size() == n and sh.btn_new.text == "Sure?")

	# settings button opens the settings page
	sh.set_left_open(false)
	sh.btn_settings.pressed.emit()
	ck.call("toolbar: Settings opens the settings page", sh.left_open and ed.settings_page.get_parent().visible and not ed.build_page.visible)
	ed._show_page(true)

	# collapsing
	var wide := sh.canvas_rect().size.x
	sh.set_left_open(false)
	ck.call("sidebars: the left one collapses on its own", not sh.left.visible and sh.right.visible and ed.panel_hidden)
	sh.set_right_open(false)
	ck.call("sidebars: both collapsed gives the canvas the whole width", not sh.right.visible and sh.canvas_rect().size.x > wide and is_equal_approx(sh.canvas_rect().size.x, vp.size.x))
	ck.call("sidebars: the collapse handles move to the window edges", is_zero_approx(sh.left_handle.offset_left) and is_zero_approx(sh.right_handle.offset_right))
	var key := InputEventKey.new()
	key.keycode = KEY_BRACKETLEFT
	key.pressed = true
	ed._unhandled_input(key)
	ck.call("sidebars: [ reopens the left sidebar", sh.left.visible)
	key = InputEventKey.new()
	key.keycode = KEY_BRACKETRIGHT
	key.pressed = true
	ed._unhandled_input(key)
	ck.call("sidebars: ] reopens the right sidebar", sh.right.visible)
	ed.set_panel_hidden(true)
	ck.call("sidebars: the old H key path collapses the left sidebar", not sh.left.visible)
	ed.set_panel_hidden(false)

	# layers
	var layer: String = sh.layer_rows.keys()[0]
	(sh.layer_rows[layer].eye as Button).pressed.emit()
	ck.call("layers: the eye hides the real layer", bool(placed.hidden_types.get(layer, false)))
	(sh.layer_rows[layer].eye as Button).pressed.emit()
	ck.call("layers: the eye shows it again", not bool(placed.hidden_types.get(layer, false)))
	(sh.layer_rows[layer].lock as Button).pressed.emit()
	ck.call("layers: the padlock locks the real layer", bool(placed.locked_types.get(layer, false)))
	(sh.layer_rows[layer].lock as Button).pressed.emit()
	ck.call("layers: the padlock unlocks it", not bool(placed.locked_types.get(layer, false)))
	ck.call("layers: one row per catalog layer", sh.layer_rows.size() == WorldEditor.layer_names().size())

	# status bar + properties follow the editor
	ed._note_until = 0
	ed.set_tool("erase")
	await tree.process_frame
	ck.call("status: the tool readout follows the active tool", "rase" in sh.st_tool.text, sh.st_tool.text)
	ed.set_tool("place", "temple_floor_center")
	await tree.process_frame
	ck.call("status: the asset readout names the chosen asset", sh.st_asset.text != "Asset: none", sh.st_asset.text)
	ck.call("status: the layer readout names its layer", sh.st_layer.text == "Layer: " + PlacedObjects.type_of("temple_floor_center"), sh.st_layer.text)
	ck.call("status: zoom and grid readouts are filled in", "%" in sh.st_zoom.text and "Snap" in sh.st_grid.text)
	ed.set_tool("select")
	var pick: Dictionary = {}
	for o: Dictionary in placed.objects:
		if PlacedObjects.def_of(o.id).kind == "tree":  # a tree: selecting a floor tile warms the art-box cache the dims test reads
			pick = o
			break
	ck.call("properties: the map has a tree to select", not pick.is_empty())
	ed.selected = pick
	ed._refresh()
	await tree.process_frame
	ck.call("properties: selecting shows the inspector and hides the empty note", ed.inspector.visible and not sh.props_empty.visible and ed.inspector.is_ancestor_of(ed.inspector_name) and sh.right.is_ancestor_of(ed.inspector))
	ed.selected = {}
	ed._refresh()
	await tree.process_frame
	ck.call("properties: nothing selected shows the empty note", not ed.inspector.visible and sh.props_empty.visible)

	# the in-game builder keeps its own orange palette
	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
	WorldEditor.use_palette(false)
	ck.call("palette: the in-game World Builder palette is restored", WorldEditor.ACCENT == Color("#FF6B00"))
