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
var overlay: Node2D
var _tool_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}
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


func set_open(v: bool) -> void:
	open = v
	panel.visible = v
	tab.visible = not v
	if not v:
		dragging = false
		selected = {}
		_clear_armed = false
	_refresh()


func set_tool(t: String, id := "") -> void:
	tool = t
	place_id = id if t == "place" else ""
	if t != "select":
		selected = {}
	_refresh()


func snapped_pos(p: Vector2) -> Vector2:
	return p if snap <= 0 else (p / float(snap)).round() * float(snap)


func _mouse_world() -> Vector2:
	return overlay.get_global_mouse_position()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			set_open(not open)
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


func delete_selected() -> void:
	if selected.is_empty():
		return
	placed.remove(selected)
	selected = {}
	dragging = false
	_refresh()


# ------------------------------------------------------------------ overlay drawing
func draw_overlay(c: Node2D) -> void:
	for tp in WorldScale.TREE_POSITIONS:
		c.draw_rect(Rect2(tp.x - WorldScale.TREE_TRUNK_FOOTPRINT.x * 0.5, tp.y - WorldScale.TREE_TRUNK_FOOTPRINT.y, WorldScale.TREE_TRUNK_FOOTPRINT.x, WorldScale.TREE_TRUNK_FOOTPRINT.y), Color(1, 1, 1, 0.25), false, 2.0)
	for o in placed.objects:
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
		if def.kind == "tree":
			var info := PlacedObjects.tree_info(int(def.tree))
			var tex := load(str(info.texture)) as Texture2D
			var anchor := Vector2(float(info.anchor[0]), float(info.anchor[1]))
			c.draw_texture(tex, pos - anchor, Color(1, 1, 1, 0.55) if ok else Color(1, 0.5, 0.5, 0.55))
		else:
			c.draw_rect(PlacedObjects.hit_rect(place_id, pos), Color(tint, 0.25))
		c.draw_rect(PlacedObjects.footprint_rect(place_id, pos), tint, true)
		c.draw_rect(PlacedObjects.footprint_rect(place_id, pos), Color(tint, 1.0), false, 3.0)


# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tab = Button.new()
	tab.name = "BuildTab"
	tab.text = "< BUILD"
	tab.focus_mode = Control.FOCUS_NONE
	tab.tooltip_text = "World Builder (F3)"
	tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tab.offset_left = -84
	tab.offset_right = 0
	tab.offset_top = 40
	tab.offset_bottom = 76
	_style_button(tab)
	tab.pressed.connect(func(): set_open(true))
	root.add_child(tab)

	panel = PanelContainer.new()
	panel.name = "BuilderPanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_W
	panel.offset_right = 0
	panel.offset_top = 90
	panel.offset_bottom = -110
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.04, 0.93)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.border_width_right = 0
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "WORLD BUILDER"
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hide := Button.new()
	hide.text = "Hide >"
	hide.focus_mode = Control.FOCUS_NONE
	_style_button(hide)
	hide.pressed.connect(func(): set_open(false))
	head.add_child(hide)

	var tools := HBoxContainer.new()
	col.add_child(tools)
	_tool_buttons["select"] = _toggle(tools, "Select / Move", func(): set_tool("select"))
	_tool_buttons["erase"] = _toggle(tools, "Erase", func(): set_tool("erase"))

	var group := ButtonGroup.new()
	for cat: Array in PlacedObjects.CATEGORIES:
		var lab := Label.new()
		lab.text = str(cat[0])
		lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		col.add_child(lab)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		col.add_child(grid)
		for id: String in cat[1]:
			var def: Dictionary = PlacedObjects.CATALOG[id]
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = group
			b.focus_mode = Control.FOCUS_NONE
			b.text = str(def.label)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 56)
			b.clip_text = true
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 40)
			if def.kind == "tree":
				var info := PlacedObjects.tree_info(int(def.tree))
				b.icon = load(str(info.texture)) as Texture2D
				b.custom_minimum_size = Vector2(0, 84)
			b.add_theme_font_size_override("font_size", 12)
			b.pressed.connect(func(): set_tool("place", id))
			grid.add_child(b)
			_palette_buttons[id] = b

	var opts := HBoxContainer.new()
	col.add_child(opts)
	snap_button = Button.new()
	snap_button.focus_mode = Control.FOCUS_NONE
	snap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(snap_button)
	snap_button.pressed.connect(_cycle_snap)
	opts.add_child(snap_button)
	var del := Button.new()
	del.text = "Delete"
	del.focus_mode = Control.FOCUS_NONE
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(del)
	del.pressed.connect(delete_selected)
	opts.add_child(del)

	var io := HBoxContainer.new()
	col.add_child(io)
	var copy := Button.new()
	copy.text = "Copy JSON"
	copy.focus_mode = Control.FOCUS_NONE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(copy)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(placed.to_json_string())
		status.text = "Copied %d objects" % placed.objects.size())
	io.add_child(copy)
	clear_button = Button.new()
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(clear_button)
	clear_button.pressed.connect(_clear_pressed)
	io.add_child(clear_button)

	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var help := Label.new()
	help.text = "Click world to place. Right-click = Select. Drag to move, Del removes. F3 toggles."
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(help)


func _toggle(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", ACCENT)


func _cycle_snap() -> void:
	snap = SNAPS[(SNAPS.find(snap) + 1) % SNAPS.size()]
	_refresh()


func _clear_pressed() -> void:
	if not _clear_armed:
		_clear_armed = true
		_refresh()
		get_tree().create_timer(2.5).timeout.connect(func():
			_clear_armed = false
			_refresh())
		return
	_clear_armed = false
	placed.clear_all()
	selected = {}
	_refresh()


func _refresh() -> void:
	if status == null:
		return
	for k: String in _tool_buttons:
		(_tool_buttons[k] as Button).set_pressed_no_signal(tool == k)
	for id: String in _palette_buttons:
		(_palette_buttons[id] as Button).set_pressed_no_signal(tool == "place" and place_id == id)
	snap_button.text = "Snap: %s" % (str(snap) if snap > 0 else "off")
	clear_button.text = "Sure? click again" if _clear_armed else "Clear all"
	var what := "placing %s" % PlacedObjects.CATALOG[place_id].label if tool == "place" else ("erase" if tool == "erase" else ("selected %s" % PlacedObjects.CATALOG[selected.id].label if not selected.is_empty() else "select / move"))
	status.text = "%d placed | %s" % [placed.objects.size(), what]
