class_name WorldEditor
extends CanvasLayer
## World Builder: a small collapsible tools panel on the RIGHT edge for placing trees, walls and other built
## objects (PlacedObjects.CATALOG) anywhere in the arena. F3 or the BUILD tab toggles it.
##   Pick an item in the palette, click the world to place it (right-click or Select to stop).
##   Select / Move: click an object to pick it, drag to move it, Delete removes it.   Erase: click objects to remove them.
## The layout autosaves (user://world_builder_layout.json). While the panel is hidden nothing is editable.
const TOGGLE_KEY := KEY_F3
const PANEL_W := 236.0
const ACCENT := Color("#FF6B00")
const SNAPS: Array[int] = [30, 15, 0]

var arena: TrainingArena
var placed: PlacedObjects
var open := false
var tool := "select"  ## "select" | "erase" | "place"
var place_id := ""
var snap := 30
var selected: Dictionary = {}
var dragging := false
var _drag_origin := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var panel: PanelContainer
var tab: Button
var status: Label
var clear_button: Button
var snap_button: Button
var save_button: Button
var _note := ""
var _note_until := 0
var overlay: Node2D
var _tool_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}
var _filter_buttons: Dictionary = {}
var _category_sections: Dictionary = {}
var palette_scroll: ScrollContainer
var _clear_armed := false
var _js_state: JavaScriptObject


class Overlay extends Node2D:
	var editor: WorldEditor
	func _init(e: WorldEditor) -> void:
		editor = e
		z_index = 200
		name = "WorldEditorOverlay"
	func _process(_d: float) -> void:
		visible = editor.open
		if visible:
			queue_redraw()
	func _draw() -> void:
		editor.draw_overlay(self)


func setup(a: TrainingArena, p: PlacedObjects) -> void:
	arena = a
	placed = p


func _ready() -> void:
	layer = 7
	name = "WorldEditor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Overlay.new(self)
	arena.add_child(overlay)
	_build_ui()
	set_open(false)
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		_js_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__EDITOR_STATE__ = _js_state
		if "editor=1" in query:
			set_open(true)


func _process(_d: float) -> void:
	if _js_state != null:
		_js_state.open = open
		_js_state.count = placed.objects.size()
		_js_state.tool = tool
		_js_state.place_id = place_id
		_js_state.selected_id = str(selected.get("id", ""))
		_js_state.selected_x = float(selected.get("pos", Vector2.ZERO).x)
		_js_state.selected_y = float(selected.get("pos", Vector2.ZERO).y)
		_js_state.scroll = palette_scroll.scroll_vertical
		if open:
			var scroll_rect := palette_scroll.get_global_rect()
			_js_state.scroll_x = scroll_rect.get_center().x
			_js_state.scroll_y = scroll_rect.get_center().y
			_js_state.scroll_h = scroll_rect.size.y
			var cards := {}
			for id: String in _palette_buttons:
				var b: Button = _palette_buttons[id]
				var r := b.get_global_rect()
				cards[id] = {"x": r.get_center().x, "y": r.get_center().y, "shown": b.is_visible_in_tree() and palette_scroll.get_global_rect().has_point(r.get_center())}
			var filters := {}
			for category: String in _filter_buttons:
				var b: CheckBox = _filter_buttons[category]
				var center := b.get_global_rect().get_center()
				filters[category] = {"x": center.x, "y": center.y, "shown": b.button_pressed}
			_js_state.cards_json = JSON.stringify(cards)
			_js_state.filters_json = JSON.stringify(filters)
			var r := panel.get_global_rect()
			_js_state.panel_x = r.position.x
			_js_state.panel_y = r.position.y
			_js_state.panel_w = r.size.x
			_js_state.panel_h = r.size.y
			_js_state.grass_count = (arena.get_node("WindGrassField") as WindGrassField).ground_count()
			_js_state.tall_count = (arena.get_node("WindGrassField") as WindGrassField).tall_count()
	if open and inspector != null and inspector.visible and not selected.is_empty():
		inspector_pos.text = "X %d   Y %d" % [int(selected.pos.x), int(selected.pos.y)]


func set_open(v: bool) -> void:
	open = v
	panel.visible = v
	tab.visible = not v
	if not v:
		dragging = false
		selected = {}
		_clear_armed = false
		_reset_armed = false
	_refresh()


func set_tool(t: String, id := "") -> void:
	tool = t
	place_id = id if t == "place" else ""
	if t != "select":
		selected = {}
	_refresh()


func snapped_pos(p: Vector2) -> Vector2:
	if snap > 0 and _grass_tool():
		var ground := (arena.get_node("WindGrassField") as WindGrassField).ground
		return ground.position + ground.map_to_local(ground.local_to_map(p - ground.position))
	return p if snap <= 0 else (p / float(snap)).round() * float(snap)

func _grass_tool() -> bool:
	var id := place_id if tool == "place" else str(selected.get("id", ""))
	return id != "" and PlacedObjects.def_of(id).kind == "grass"


func _mouse_world() -> Vector2:
	return overlay.get_global_mouse_position()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			set_open(not open)
			get_viewport().set_input_as_handled()
			return
		if open and event.keycode == KEY_S and event.ctrl_pressed:
			save_now()
			get_viewport().set_input_as_handled()
			return
		if open and (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and not selected.is_empty():
			delete_selected()
			get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press(_mouse_world())
			else:
				release()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			set_tool("select")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		drag_to(_mouse_world())


func press(world: Vector2) -> void:
	match tool:
		"place":
			var pos := snapped_pos(world)
			if placed.can_place(place_id, pos):
				selected = {}
				placed.add(place_id, pos)
				_refresh()
		"erase":
			var o := placed.hit_test(world)
			if not o.is_empty():
				placed.remove(o)
				_refresh()
		_:
			selected = placed.hit_test(world)
			dragging = not selected.is_empty()
			if dragging:
				_drag_origin = selected.pos
				_drag_offset = (selected.pos as Vector2) - world
			_refresh()


func drag_to(world: Vector2) -> void:
	if dragging and not selected.is_empty():
		placed.move(selected, snapped_pos(world + _drag_offset), false)


func release() -> void:
	if not dragging:
		return
	dragging = false
	if selected.is_empty():
		return
	if placed.can_place(selected.id, selected.pos):
		placed.move(selected, selected.pos, true)
	else:
		placed.move(selected, _drag_origin, true)  # dropped somewhere illegal: snap back
	_refresh()


## Explicit save: writes the layout to the game's save slot (it also autosaves on every edit) and says so.
func save_now() -> bool:
	var ok := placed.save()
	_flash("SAVED  %d objects" % placed.objects.size() if ok else "SAVE FAILED")
	return ok


## Hand the layout over as a file (web: browser download; desktop: copied to the clipboard).
func download_layout() -> void:
	var json := placed.to_json_string()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(json.to_utf8_buffer(), "shinobi_world_layout.json", "application/json")
		_flash("DOWNLOADED shinobi_world_layout.json")
	else:
		DisplayServer.clipboard_set(json)
		_flash("Layout copied to clipboard")


func _flash(text: String) -> void:
	_note = text
	_note_until = Time.get_ticks_msec() + 2500
	_refresh()
	get_tree().create_timer(2.6).timeout.connect(_refresh)


func delete_selected() -> void:
	if selected.is_empty():
		return
	placed.remove(selected)
	selected = {}
	dragging = false
	_refresh()


# ------------------------------------------------------------------ overlay drawing
func draw_overlay(c: Node2D) -> void:
	for o in placed.objects:
		if not placed.type_visible(o.id):
			continue
		var sel: bool = (o == selected)
		c.draw_rect(PlacedObjects.footprint_rect(o.id, o.pos), Color(1, 0.84, 0.2, 0.95) if sel else Color(ACCENT, 0.6), false, 4.0 if sel else 2.0)
		if sel:
			c.draw_rect(PlacedObjects.hit_rect(o.id, o.pos), Color(1, 0.84, 0.2, 0.5), false, 2.0)
	if tool == "erase" and get_viewport().gui_get_hovered_control() == null:
		var h := placed.hit_test(_mouse_world())
		if not h.is_empty():
			c.draw_rect(PlacedObjects.hit_rect(h.id, h.pos), Color(1, 0.2, 0.2, 0.9), false, 3.0)
	if tool == "place" and place_id != "" and get_viewport().gui_get_hovered_control() == null:
		var pos := snapped_pos(_mouse_world())
		var ok := placed.can_place(place_id, pos)
		var tint := Color(0.4, 1, 0.5, 0.55) if ok else Color(1, 0.3, 0.3, 0.55)
		var def: Dictionary = PlacedObjects.CATALOG[place_id]
		if def.kind == "grass":
			var tex := load(WindGrassTileset.DIR + place_id + ".png") as Texture2D
			c.draw_texture(tex, pos - Vector2(56, 136 if def.tall else 84), Color(1, 1, 1, 0.55))
		elif def.kind == "tree":
			var info := PlacedObjects.tree_info(int(def.tree))
			var tex := load(str(info.texture)) as Texture2D
			var anchor := Vector2(float(info.anchor[0]), float(info.anchor[1]))
			c.draw_texture(tex, pos - anchor, Color(1, 1, 1, 0.55) if ok else Color(1, 0.5, 0.5, 0.55))
		else:
			c.draw_rect(PlacedObjects.hit_rect(place_id, pos), Color(tint, 0.25))
		c.draw_rect(PlacedObjects.footprint_rect(place_id, pos), tint, true)
		c.draw_rect(PlacedObjects.footprint_rect(place_id, pos), Color(tint, 1.0), false, 3.0)


# ------------------------------------------------------------------ UI
const BG := Color("#0c0c10")
const CARD := Color("#16161c")
const CARD_HOVER := Color("#1f1f27")
const EDGE := Color("#2b2b35")
const DANGER := Color("#ff4d4d")
const MUTED := Color(1, 1, 1, 0.55)

var inspector: PanelContainer
var inspector_name: Label
var inspector_pos: Label
var count_label: Label
var reset_button: Button
var _reset_armed := false


static func _sbox(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## kind: "card" (palette), "tool" (segmented), "ghost" (small action), "danger".
func _skin(b: Button, kind := "ghost") -> void:
	var base := CARD
	var edge := EDGE
	var hover_edge := ACCENT
	var press_bg := Color(ACCENT, 0.18)
	var text := Color.WHITE
	match kind:
		"tool":
			press_bg = ACCENT
		"danger":
			edge = Color(DANGER, 0.45)
			hover_edge = DANGER
			press_bg = Color(DANGER, 0.25)
			text = Color("#ffb3b3")
	b.add_theme_stylebox_override("normal", _sbox(base, edge, 1))
	b.add_theme_stylebox_override("hover", _sbox(CARD_HOVER, hover_edge, 1))
	b.add_theme_stylebox_override("pressed", _sbox(press_bg, hover_edge, 2))
	b.add_theme_stylebox_override("hover_pressed", _sbox(press_bg, hover_edge, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", text)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var on := Color("#0a0a0a") if kind == "tool" else Color.WHITE
	b.add_theme_color_override("font_pressed_color", on)
	b.add_theme_color_override("font_hover_pressed_color", on)
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _section(col: Control, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var lab := Label.new()
	lab.text = title.to_upper()
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", MUTED)
	row.add_child(lab)
	var line := ColorRect.new()
	line.color = EDGE
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)


## Small procedural thumbnail for block items (front face, lit roof, shaded side) so the palette shows what you get.
static func block_icon(id: String) -> Texture2D:
	var def: Dictionary = PlacedObjects.CATALOG[id]
	var fp: Vector2 = def.footprint
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var scale_f := 30.0 / maxf(fp.x, float(def.height) + fp.y * 0.5)
	var w := int(clampf(fp.x * scale_f, 14.0, 34.0))
	var h := int(clampf(float(def.height) * scale_f, 12.0, 28.0))
	var d := int(clampf(fp.y * scale_f * 0.5, 4.0, 12.0))
	var x0 := int((48 - w - d) * 0.5)
	var y0 := int((48 - h - d) * 0.5) + d
	img.fill_rect(Rect2i(x0, y0, w, h), Color("#8a8f99"))
	img.fill_rect(Rect2i(x0 + w, y0 - d + 2, d, h), Color("#555a63"))
	img.fill_rect(Rect2i(x0 + 2, y0 - d, w, d), Color("#b9bfca"))
	img.fill_rect(Rect2i(x0, y0 + h - 3, w, 3), Color("#6a6f78"))
	return ImageTexture.create_from_image(img)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tab = Button.new()
	tab.name = "BuildTab"
	tab.text = "<  BUILD"
	tab.focus_mode = Control.FOCUS_NONE
	tab.tooltip_text = "World Builder (F3)"
	tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tab.offset_left = -92
	tab.offset_right = 0
	tab.offset_top = 40
	tab.offset_bottom = 80
	_skin(tab, "card")
	var tab_sb := _sbox(Color(BG, 0.94), ACCENT, 2, 0)
	tab_sb.corner_radius_top_left = 10
	tab_sb.corner_radius_bottom_left = 10
	tab_sb.border_width_right = 0
	tab.add_theme_stylebox_override("normal", tab_sb)
	tab.add_theme_color_override("font_color", ACCENT)
	tab.pressed.connect(func(): set_open(true))
	root.add_child(tab)

	panel = PanelContainer.new()
	panel.name = "BuilderPanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_W
	panel.offset_right = 0
	panel.offset_top = 56
	panel.offset_bottom = -24
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	panel.add_to_group("world_builder_ui")
	var sb := _sbox(Color(BG, 0.95), Color(ACCENT, 0.85), 2, 12)
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_right = 0
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	# header
	var head := HBoxContainer.new()
	outer.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	var title := Label.new()
	title.text = "WORLD BUILDER"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color.WHITE)
	titles.add_child(title)
	var sub := Label.new()
	sub.text = "SHINOBI RUSH   |   F3"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", ACCENT)
	titles.add_child(sub)
	var hide := Button.new()
	hide.text = "HIDE  >"
	hide.focus_mode = Control.FOCUS_NONE
	hide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(hide)
	hide.pressed.connect(func(): set_open(false))
	head.add_child(hide)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(0, 3)
	outer.add_child(bar)

	# tools
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	outer.add_child(tools)
	_tool_buttons["select"] = _toggle(tools, "SELECT / MOVE", func(): set_tool("select"))
	_tool_buttons["erase"] = _toggle(tools, "ERASE", func(): set_tool("erase"))

	# Visibility filters also isolate picking; no layout data or collision is removed.
	var filters := GridContainer.new()
	filters.columns = 2
	outer.add_child(filters)
	for category: Array in PlacedObjects.CATEGORIES:
		var name := str(category[0])
		var check := CheckBox.new()
		check.text = "Walls" if name == "Walls & blocks" else name
		check.tooltip_text = "Show/hide " + name.to_lower() + " in the world and palette"
		check.button_pressed = true
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_size_override("font_size", 11)
		check.toggled.connect(func(shown: bool): set_type_filter(name, shown))
		filters.add_child(check)
		_filter_buttons[name] = check

	# palette (scrolls)
	var scroll := ScrollContainer.new()
	palette_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var group := ButtonGroup.new()
	for cat: Array in PlacedObjects.CATEGORIES:
		var section := VBoxContainer.new()
		col.add_child(section)
		_category_sections[str(cat[0])] = section
		_section(section, str(cat[0]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		section.add_child(grid)
		for id: String in cat[1]:
			var def: Dictionary = PlacedObjects.CATALOG[id]
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = group
			b.focus_mode = Control.FOCUS_NONE
			b.text = str(def.label)
			b.tooltip_text = "Place: %s" % str(def.label)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			if def.kind == "grass":
				b.icon = load(WindGrassTileset.DIR + id + ".png") as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "tree":
				b.icon = load(str(PlacedObjects.tree_info(int(def.tree)).texture)) as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			else:
				b.icon = block_icon(id)
				b.add_theme_constant_override("icon_max_width", 44)
				b.custom_minimum_size = Vector2(0, 76)
			_skin(b, "card")
			b.add_theme_font_size_override("font_size", 11)
			b.pressed.connect(func(): set_tool("place", id))
			grid.add_child(b)
			_palette_buttons[id] = b

	# inspector card (only while something is selected)
	inspector = PanelContainer.new()
	inspector.add_theme_stylebox_override("panel", _sbox(CARD, Color(1, 0.84, 0.2, 0.7), 1, 8))
	outer.add_child(inspector)
	var ib := HBoxContainer.new()
	ib.add_theme_constant_override("separation", 8)
	inspector.add_child(ib)
	var itxt := VBoxContainer.new()
	itxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	itxt.add_theme_constant_override("separation", 0)
	ib.add_child(itxt)
	inspector_name = Label.new()
	inspector_name.add_theme_font_size_override("font_size", 14)
	inspector_name.add_theme_color_override("font_color", Color(1, 0.84, 0.2))
	itxt.add_child(inspector_name)
	inspector_pos = Label.new()
	inspector_pos.add_theme_font_size_override("font_size", 11)
	inspector_pos.add_theme_color_override("font_color", MUTED)
	itxt.add_child(inspector_pos)
	var del := Button.new()
	del.text = "DELETE"
	del.focus_mode = Control.FOCUS_NONE
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(del, "danger")
	del.pressed.connect(delete_selected)
	ib.add_child(del)

	# save row
	var saves := HBoxContainer.new()
	saves.add_theme_constant_override("separation", 6)
	outer.add_child(saves)
	save_button = Button.new()
	save_button.text = "SAVE  (Ctrl+S)"
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.custom_minimum_size = Vector2(0, 38)
	_skin(save_button, "tool")
	save_button.add_theme_stylebox_override("normal", _sbox(ACCENT, Color("#ffa05a"), 1, 8))
	save_button.add_theme_stylebox_override("hover", _sbox(Color("#ff8a2e"), Color.WHITE, 1, 8))
	save_button.add_theme_stylebox_override("pressed", _sbox(Color("#cc5500"), Color.WHITE, 2, 8))
	save_button.add_theme_color_override("font_color", Color("#0a0a0a"))
	save_button.add_theme_color_override("font_hover_color", Color("#0a0a0a"))
	save_button.pressed.connect(save_now)
	saves.add_child(save_button)
	var dl := Button.new()
	dl.text = "DOWNLOAD"
	dl.tooltip_text = "Download the layout as a .json file"
	dl.focus_mode = Control.FOCUS_NONE
	dl.custom_minimum_size = Vector2(0, 38)
	_skin(dl)
	dl.pressed.connect(download_layout)
	saves.add_child(dl)

	# options
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 6)
	outer.add_child(opts)
	snap_button = Button.new()
	snap_button.focus_mode = Control.FOCUS_NONE
	snap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(snap_button)
	snap_button.pressed.connect(_cycle_snap)
	opts.add_child(snap_button)
	var copy := Button.new()
	copy.text = "COPY JSON"
	copy.focus_mode = Control.FOCUS_NONE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(copy)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(placed.to_json_string())
		status.text = "Copied to clipboard")
	opts.add_child(copy)
	var io := HBoxContainer.new()
	io.add_theme_constant_override("separation", 6)
	outer.add_child(io)
	reset_button = Button.new()
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(reset_button)
	reset_button.pressed.connect(_reset_pressed)
	io.add_child(reset_button)
	clear_button = Button.new()
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(clear_button, "danger")
	clear_button.pressed.connect(_clear_pressed)
	io.add_child(clear_button)

	# footer
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _sbox(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0, 6))
	outer.add_child(foot)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	foot.add_child(fv)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	fv.add_child(count_label)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", ACCENT)
	status.clip_text = true
	fv.add_child(status)
	var hints := GridContainer.new()
	hints.columns = 2
	hints.add_theme_constant_override("h_separation", 14)
	fv.add_child(hints)
	for line in ["Click: place", "Right-click: cancel", "Drag: move", "Del: remove"]:
		var help := Label.new()
		help.text = line
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help.add_theme_font_size_override("font_size", 11)
		help.add_theme_color_override("font_color", MUTED)
		hints.add_child(help)


func set_type_filter(category: String, shown: bool) -> void:
	placed.set_type_visible(category, shown)
	(_category_sections[category] as Control).visible = shown
	(_filter_buttons[category] as CheckBox).set_pressed_no_signal(shown)
	if not shown:
		if not selected.is_empty() and PlacedObjects.type_of(selected.id) == category:
			selected = {}
			dragging = false
		if place_id != "" and PlacedObjects.type_of(place_id) == category:
			set_tool("select")
	_refresh()


func _toggle(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 38)
	_skin(b, "tool")
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _cycle_snap() -> void:
	snap = SNAPS[(SNAPS.find(snap) + 1) % SNAPS.size()]
	_refresh()


func _armed_button(armed_flag: String) -> void:
	set(armed_flag, true)
	_refresh()
	get_tree().create_timer(2.5).timeout.connect(func():
		set(armed_flag, false)
		_refresh())


func _clear_pressed() -> void:
	if not _clear_armed:
		_armed_button("_clear_armed")
		return
	_clear_armed = false
	placed.clear_all()
	selected = {}
	_refresh()


## Back to the original arena: the five starting trees, everything you built removed.
func _reset_pressed() -> void:
	if not _reset_armed:
		_armed_button("_reset_armed")
		return
	_reset_armed = false
	placed.load_dict({"version": 1, "items": []})
	selected = {}
	_refresh()


func _refresh() -> void:
	if status == null:
		return
	for k: String in _tool_buttons:
		(_tool_buttons[k] as Button).set_pressed_no_signal(tool == k)
	for id: String in _palette_buttons:
		(_palette_buttons[id] as Button).set_pressed_no_signal(tool == "place" and place_id == id)
	snap_button.text = "GRASS GRID" if snap > 0 and _grass_tool() else "SNAP  %s" % (str(snap) if snap > 0 else "OFF")
	clear_button.text = "SURE?" if _clear_armed else "CLEAR ALL"
	reset_button.text = "SURE?" if _reset_armed else "RESET"
	inspector.visible = not selected.is_empty()
	if not selected.is_empty():
		inspector_name.text = str(PlacedObjects.def_of(selected.id).label)
		inspector_pos.text = "X %d   Y %d" % [int(selected.pos.x), int(selected.pos.y)]
	var what := "Placing: %s" % str(PlacedObjects.CATALOG[place_id].label) if tool == "place" else ("Erase mode" if tool == "erase" else "Select / move")
	count_label.text = "%d objects" % placed.objects.size()
	status.text = _note if Time.get_ticks_msec() < _note_until else what
