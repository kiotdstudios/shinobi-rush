class_name EditorShell
extends Control
## The all-black Shinobi Rush Map Editor chrome: a top toolbar, a left sidebar (the build tools), a right sidebar
## (layers + properties) and a bottom status bar. It owns NO editing logic: every control calls a WorldEditor /
## PlacedObjects function, and every readout is read back from them each frame, so the shell and the canvas
## can never disagree about the tool, the selection, the layers or the undo state.
## The world is the full-screen canvas behind the sidebars; the sidebars overlay it and swallow their own mouse input.

const TOP_H := 48.0
const STATUS_H := 34.0
const LEFT_W := 300.0
const RIGHT_W := 260.0
const HANDLE_W := 18.0

var editor: WorldEditor
var left: PanelContainer
var right: PanelContainer
var toolbar: PanelContainer
var status_bar: PanelContainer
var left_open := true
var right_open := true

var btn_new: Button
var btn_save: Button
var btn_undo: Button
var btn_redo: Button
var btn_play: Button
var btn_grid: Button
var btn_snap: Button
var btn_settings: Button
var view_menu: MenuButton
var left_handle: Button
var right_handle: Button
var layer_rows: Dictionary = {}  ## layer name -> {"eye": Button, "lock": Button}
var props_empty: Label
var st_tool: Label
var st_asset: Label
var st_layer: Label
var st_cursor: Label
var st_zoom: Label
var st_grid: Label
var st_save: Label
var _centered := false
var _frames := 0


## Small drawn glyphs (no icon font needed): an eye and a padlock, on or off.
class Glyph extends Control:
	var kind := "eye"
	var on := true
	func _init(k: String) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var c := size * 0.5
		var col := Color("#F5F5F5") if on else Color("#6a6a6a")
		if kind == "eye":
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0 * 2.0 - 1.0
				var h := 5.0 * (1.0 - t * t)
				top.append(c + Vector2(t * 8.0, -h))
				bottom.append(c + Vector2(t * 8.0, h))
			bottom.reverse()
			top.append_array(bottom)
			top.append(top[0])
			draw_polyline(top, col, 1.5)
			draw_circle(c, 2.4, col)
			if not on:
				draw_line(c + Vector2(-8, 7), c + Vector2(8, -7), col, 1.6)
		else:
			draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 8)), col)
			if on:
				draw_arc(c + Vector2(0, -1), 3.6, PI, TAU, 12, col, 1.6)
				draw_line(c + Vector2(-3.6, -1), c + Vector2(-3.6, 1), col, 1.6)
				draw_line(c + Vector2(3.6, -1), c + Vector2(3.6, 1), col, 1.6)
			else:
				draw_arc(c + Vector2(5.5, -2), 3.6, PI, TAU * 0.92, 12, col, 1.6)
				draw_line(c + Vector2(1.9, -2), c + Vector2(1.9, -1), col, 1.6)


func _init(e: WorldEditor) -> void:
	editor = e
	name = "EditorShell"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func flat(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func build() -> void:
	_build_toolbar()
	_build_left()
	_build_right()
	_build_status()
	_build_handles()
	_apply_layout()
	refresh()


# ------------------------------------------------------------------ toolbar
func _tb(parent: Node, text: String, tip: String, cb: Callable, toggle := false, width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 34)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", flat(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", flat(WorldEditor.CARD_HOVER))
	b.add_theme_stylebox_override("pressed", flat(WorldEditor.CARD, WorldEditor.ACCENT, 1))
	b.add_theme_stylebox_override("hover_pressed", flat(WorldEditor.CARD_HOVER, WorldEditor.ACCENT, 1))
	b.add_theme_stylebox_override("disabled", flat(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("#F5F5F5"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#4a4a4a"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if toggle:
		b.toggled.connect(func(_on: bool) -> void: cb.call())
	else:
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _sep(parent: Node) -> void:
	var s := ColorRect.new()
	s.color = WorldEditor.EDGE
	s.custom_minimum_size = Vector2(1, 26)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(s)


func _build_toolbar() -> void:
	toolbar = PanelContainer.new()
	toolbar.name = "Toolbar"
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = TOP_H
	toolbar.add_theme_stylebox_override("panel", flat(Color("#101010"), WorldEditor.EDGE, 0, 0))
	(toolbar.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 1
	add_child(toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	toolbar.add_child(row)
	var title := Label.new()
	title.text = "SHINOBI RUSH  -  MAP EDITOR"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#F5F5F5"))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	row.add_child(gap)
	_sep(row)
	btn_new = _tb(row, "New", "Clear the whole map (click twice to confirm)", _on_new)
	btn_save = _tb(row, "Save", "Save the map (Ctrl+S)", editor.save_now)
	_sep(row)
	btn_undo = _tb(row, "Undo", "Undo (Ctrl+Z)", editor.undo)
	btn_redo = _tb(row, "Redo", "Redo (Ctrl+Y or Ctrl+Shift+Z)", editor.redo)
	_sep(row)
	btn_play = _tb(row, "Playtest", "Open the game in a new tab (browser only)", _on_playtest)
	_sep(row)
	btn_grid = _tb(row, "Grid", "Show the floor grid (G)", _on_grid, true)
	btn_snap = _tb(row, "Snapping", "Snap placement to the grid on / off", _on_snap, true)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	view_menu = MenuButton.new()
	view_menu.text = "View"
	view_menu.flat = true
	view_menu.focus_mode = Control.FOCUS_NONE
	view_menu.custom_minimum_size = Vector2(64, 34)
	view_menu.add_theme_color_override("font_color", Color("#F5F5F5"))
	view_menu.add_theme_color_override("font_hover_color", Color.WHITE)
	view_menu.add_theme_font_size_override("font_size", 12)
	var pop := view_menu.get_popup()
	pop.add_check_item("Left sidebar    [", 0)
	pop.add_check_item("Right sidebar    ]", 1)
	pop.add_check_item("Floor grid    G", 2)
	pop.add_check_item("Snap to grid", 3)
	pop.add_theme_stylebox_override("panel", flat(Color("#101010"), WorldEditor.EDGE, 1, 4))
	pop.add_theme_stylebox_override("hover", flat(Color("#2a2a2a")))
	pop.add_theme_color_override("font_color", Color("#F5F5F5"))
	pop.add_theme_color_override("font_hover_color", Color.WHITE)
	pop.id_pressed.connect(_on_view_item)
	row.add_child(view_menu)
	btn_settings = _tb(row, "Settings", "Vision switches, camera zoom and dimension overlays", _on_settings)


func _on_new() -> void:
	editor._clear_pressed()  # the same two-click confirm as CLEAR ALL
	btn_new.text = "Sure?" if editor._clear_armed else "New"


func _on_playtest() -> void:
	MapEditorMode.open_page("index.html")


func _on_grid() -> void:
	editor.show_grid = btn_grid.button_pressed
	refresh()


func _on_snap() -> void:
	editor.snap = 30 if btn_snap.button_pressed else 0
	editor._refresh()


func _on_settings() -> void:
	set_left_open(true)
	if editor.tab_settings_button != null:
		editor.tab_settings_button.button_pressed = true
		editor._show_page(false)


func _on_view_item(id: int) -> void:
	match id:
		0:
			set_left_open(not left_open)
		1:
			set_right_open(not right_open)
		2:
			editor.show_grid = not editor.show_grid
		3:
			editor.snap = 0 if editor.snap > 0 else 30
			editor._refresh()
	refresh()


# ------------------------------------------------------------------ sidebars
func _build_left() -> void:
	left = PanelContainer.new()
	left.name = "LeftSidebar"
	left.add_theme_stylebox_override("panel", flat(Color("#101010"), WorldEditor.EDGE, 0, 0))
	(left.get_theme_stylebox("panel") as StyleBoxFlat).border_width_right = 1
	(left.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(0)
	add_child(left)
	var panel := editor.panel
	panel.get_parent().remove_child(panel)
	left.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := flat(Color("#101010"), Color(0, 0, 0, 0), 0, 0)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	# The old orange title bar and its HIDE button are replaced by this chrome.
	for key: String in ["head", "bar"]:
		if editor._ui.has(key):
			(editor._ui[key] as Control).visible = false
	editor.tab.visible = false
	squeeze(panel)
	editor.set_pro_tools_open(false)  # the palette gets the room; AUTO-TILE & TOOLS opens on demand
	# Layers + Properties move to the right sidebar.
	for n: Variant in editor._ui.get("old_layers", []):
		if is_instance_valid(n):
			(n as Control).visible = false


## The 300px sidebar must never be pushed wider by long captions: labels wrap, small buttons get tighter padding.
func squeeze(n: Node) -> void:
	for c in n.get_children():
		if c is Button and not editor.palette_scroll.is_ancestor_of(c):
			var b := c as Button
			b.add_theme_font_size_override("font_size", 11)
			for sn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var st := b.get_theme_stylebox(sn)
				if st is StyleBoxFlat:
					(st as StyleBoxFlat).content_margin_left = 4
					(st as StyleBoxFlat).content_margin_right = 4
		elif c is Label:
			var l := c as Label
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.x = 0
		squeeze(c)


func _section_title(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#F5F5F5"))
	parent.add_child(l)
	var line := ColorRect.new()
	line.color = WorldEditor.EDGE
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


func _build_right() -> void:
	right = PanelContainer.new()
	right.name = "RightSidebar"
	var sb := flat(Color("#101010"), WorldEditor.EDGE, 0, 0)
	sb.border_width_left = 1
	sb.set_content_margin_all(0)
	right.add_theme_stylebox_override("panel", sb)
	add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	_section_title(col, "LAYERS")
	var hint := Label.new()
	hint.text = "Eye hides a layer. Lock keeps it from being picked, moved, erased or painted over."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", WorldEditor.MUTED)
	col.add_child(hint)
	var layer_scroll := ScrollContainer.new()
	layer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer_scroll.custom_minimum_size = Vector2(0, 300)
	col.add_child(layer_scroll)
	var layer_col := VBoxContainer.new()
	layer_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_col.add_theme_constant_override("separation", 2)
	layer_scroll.add_child(layer_col)
	for nm: String in WorldEditor.layer_names():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		layer_col.add_child(r)
		var eye := _glyph_button(r, "eye", "Show / hide " + nm, func() -> void:
			editor.set_layer_hidden(nm, not bool(editor.placed.hidden_types.get(nm, false)))
			refresh())
		var lab := Label.new()
		lab.text = nm
		lab.clip_text = true
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", Color("#F5F5F5"))
		r.add_child(lab)
		var lk := _glyph_button(r, "lock", "Lock / unlock " + nm, func() -> void:
			editor.set_layer_locked(nm, not bool(editor.placed.locked_types.get(nm, false)))
			refresh())
		layer_rows[nm] = {"eye": eye, "lock": lk}

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	_section_title(col, "PROPERTIES")
	props_empty = Label.new()
	props_empty.text = "Nothing selected. Use SELECT / MOVE and click an object."
	props_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	props_empty.add_theme_font_size_override("font_size", 11)
	props_empty.add_theme_color_override("font_color", WorldEditor.MUTED)
	col.add_child(props_empty)
	var insp := editor.inspector
	insp.get_parent().remove_child(insp)
	col.add_child(insp)
	insp.add_theme_stylebox_override("panel", flat(WorldEditor.CARD, WorldEditor.EDGE, 1, 4))


func _glyph_button(parent: Node, kind: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = false
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(30, 26)
	for sn: String in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(sn, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", flat(WorldEditor.CARD_HOVER))
	b.add_theme_stylebox_override("hover_pressed", flat(WorldEditor.CARD_HOVER))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	var g := Glyph.new(kind)
	b.add_child(g)
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ status bar
func _status_label(parent: Node, min_w := 0.0) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#F5F5F5"))
	l.custom_minimum_size = Vector2(min_w, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	parent.add_child(l)
	return l


func _build_status() -> void:
	status_bar = PanelContainer.new()
	status_bar.name = "StatusBar"
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.offset_top = -STATUS_H
	var sb := flat(Color("#101010"), WorldEditor.EDGE, 0, 0)
	sb.border_width_top = 1
	status_bar.add_theme_stylebox_override("panel", sb)
	add_child(status_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	status_bar.add_child(row)
	st_tool = _status_label(row)
	st_tool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(row)
	st_asset = _status_label(row, 150)
	_sep(row)
	st_layer = _status_label(row, 120)
	_sep(row)
	st_cursor = _status_label(row, 120)
	_sep(row)
	st_zoom = _status_label(row, 70)
	_sep(row)
	st_grid = _status_label(row, 130)
	_sep(row)
	st_save = _status_label(row, 90)


# ------------------------------------------------------------------ collapse handles + layout
func _build_handles() -> void:
	left_handle = _handle("<", "Collapse the left sidebar  [", func() -> void: set_left_open(not left_open))
	right_handle = _handle(">", "Collapse the right sidebar  ]", func() -> void: set_right_open(not right_open))


func _handle(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", flat(Color("#101010"), WorldEditor.EDGE, 1, 3))
	b.add_theme_stylebox_override("hover", flat(Color("#2a2a2a"), WorldEditor.EDGE, 1, 3))
	b.add_theme_stylebox_override("pressed", flat(Color("#2a2a2a"), WorldEditor.EDGE, 1, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("#F5F5F5"))
	b.pressed.connect(cb)
	add_child(b)
	return b


func set_left_open(on: bool) -> void:
	left_open = on
	editor.panel_hidden = not on
	_apply_layout()


func set_right_open(on: bool) -> void:
	right_open = on
	_apply_layout()


func _apply_layout() -> void:
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 0
	left.offset_right = LEFT_W
	left.offset_top = TOP_H
	left.offset_bottom = -STATUS_H
	left.visible = left_open
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -RIGHT_W
	right.offset_right = 0
	right.offset_top = TOP_H
	right.offset_bottom = -STATUS_H
	right.visible = right_open
	var lx := LEFT_W if left_open else 0.0
	left_handle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_handle.offset_left = lx
	left_handle.offset_right = lx + HANDLE_W
	left_handle.offset_top = TOP_H + 8
	left_handle.offset_bottom = TOP_H + 52
	left_handle.text = "<" if left_open else ">"
	var rx := RIGHT_W if right_open else 0.0
	right_handle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_handle.offset_left = -rx - HANDLE_W
	right_handle.offset_right = -rx
	right_handle.offset_top = TOP_H + 8
	right_handle.offset_bottom = TOP_H + 52
	right_handle.text = ">" if right_open else "<"


## The part of the window the world canvas actually owns (between the toolbar, the sidebars and the status bar).
func canvas_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var l := LEFT_W if left_open else 0.0
	var r := RIGHT_W if right_open else 0.0
	return Rect2(l, TOP_H, vp.x - l - r, vp.y - TOP_H - STATUS_H)


## One-time: shift the camera so the map's centre sits in the middle of the free canvas, not behind a sidebar.
func center_canvas() -> bool:
	var cam := editor._camera()
	if cam == null:
		return false
	var c := canvas_rect().get_center() - get_viewport_rect().size * 0.5
	cam.offset -= c / cam.zoom
	cam.force_update_scroll()
	return true


# ------------------------------------------------------------------ live readouts
func _process(_d: float) -> void:
	_frames += 1
	if _frames == 30 or _frames == 240:  # the Settings rows are adopted into the panel a little after startup
		squeeze(editor.panel)
	if not _centered and editor._map_world_frozen:
		_centered = center_canvas()
	refresh()


func refresh() -> void:
	if editor == null or st_tool == null:
		return
	btn_undo.disabled = not editor.placed.can_undo()
	btn_redo.disabled = not editor.placed.can_redo()
	btn_play.disabled = not OS.has_feature("web")
	if btn_play.disabled:
		btn_play.tooltip_text = "Playtest opens the game in a new browser tab (browser build only)"
	btn_grid.set_pressed_no_signal(editor.show_grid)
	btn_snap.set_pressed_no_signal(editor.snap > 0)
	if not editor._clear_armed and btn_new.text != "New":
		btn_new.text = "New"
	var pop := view_menu.get_popup()
	pop.set_item_checked(0, left_open)
	pop.set_item_checked(1, right_open)
	pop.set_item_checked(2, editor.show_grid)
	pop.set_item_checked(3, editor.snap > 0)
	for nm: String in layer_rows:
		var hidden := bool(editor.placed.hidden_types.get(nm, false))
		var locked := bool(editor.placed.locked_types.get(nm, false))
		((layer_rows[nm].eye as Button).get_child(0) as Glyph).on = not hidden
		((layer_rows[nm].lock as Button).get_child(0) as Glyph).on = locked
		(layer_rows[nm].eye as Button).get_child(0).queue_redraw()
		(layer_rows[nm].lock as Button).get_child(0).queue_redraw()
	props_empty.visible = not editor.inspector.visible
	st_tool.text = editor.status.text
	var asset_id := editor.place_id
	if asset_id == "" and not editor.selected.is_empty():
		asset_id = str(editor.selected.id)
	st_asset.text = "Asset: %s" % (str(PlacedObjects.def_of(asset_id).label) if asset_id != "" else "none")
	st_layer.text = "Layer: %s" % (PlacedObjects.type_of(asset_id) if asset_id != "" else "-")
	var mw := editor._mouse_world()
	st_cursor.text = "X: %d   Y: %d" % [int(mw.x), int(mw.y)]
	var cam := editor._camera()
	st_zoom.text = "Zoom: %d%%" % int(round((cam.zoom.x / WorldScale.CAMERA_BASE_ZOOM) * 100.0)) if cam != null else "Zoom: -"
	st_grid.text = "Grid: %s   Snap: %s" % ["on" if editor.show_grid else "off", str(editor.snap) if editor.snap > 0 else "off"]
	st_save.text = "Autosave on" if editor.placed.autosave else "Autosave off"
