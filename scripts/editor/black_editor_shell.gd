class_name BlackEditorShell
extends Control
## Black map-editor chrome around the game view: a 48px toolbar, a left sidebar (assets / settings), a right
## sidebar (properties / layers / minimap) and a 26px status bar. The centre stays mouse-transparent so the
## WorldEditor's _unhandled_input keeps owning every canvas click. The legacy WorldEditor controls are adopted
## (reparented, never rebuilt), so every existing editor reference keeps pointing at a live node.

const TOOLBAR_H := 48.0
const STATUS_H := 26.0
const LEFT_W := 300.0
const RIGHT_W := 260.0
const LEFT_W_COMPACT := 260.0
const RIGHT_W_COMPACT := 230.0
const COMPACT_BELOW := 1100.0
const NARROW_BELOW := 900.0

const BG := Color("#080808")
const PANEL := Color("#111111")
const RAISED := Color("#171717")
const HOVER := Color("#1f1f1f")
const ACTIVE := Color("#2a2a2a")
const BORDER := Color("#292929")
const TEXT := Color("#F5F5F5")
const SECONDARY := Color("#A0A0A0")
const DISABLED := Color("#5a5a5a")
const DANGER_TEXT := Color("#e08a8a")
const LEGACY_DANGER_TEXT := Color("#ffb3b3")

const VIEW_LEFT := 0
const VIEW_RIGHT := 1
const VIEW_LEGACY := 2
const VIEW_BUILD := 10
const VIEW_SETTINGS := 11
const VIEW_COLLISION := 20
const VIEW_LIGHTING := 21
const VIEW_NAVIGATION := 22

const WEB_OPEN_HOOK := "__blackEditorOpenFile"

var editor: WorldEditor
var toolbar_panel: PanelContainer
var toolbar: HBoxContainer
var left_panel: PanelContainer
var right_panel: PanelContainer
var status_panel: PanelContainer
var dock: HBoxContainer  ## the status bar row
var center: Control
var left_content: VBoxContainer
var right_content: VBoxContainer
var asset_content: VBoxContainer
var properties_content: VBoxContainer
var minimap_content: VBoxContainer
var legacy_build_scroll: ScrollContainer
var toolbar_buttons: Dictionary = {}
var status_labels: Dictionary = {}
var page_buttons: Dictionary = {}
var view_menu: MenuButton
var file_dialog: FileDialog
var left_open := true
var right_open := true
var legacy_open := false
var left_width := LEFT_W
var right_width := RIGHT_W
var state: Dictionary:
	get:
		return editor_state()

var _sections: Dictionary = {}  ## content VBox -> its header Label
var _no_selection: Label
var _was_narrow := false
var _right_auto_collapsed := false
var _last_panel_hidden := false
var _last_snap := 30
var _skin_roots: Array[Node] = []
var _skin_queue: Dictionary = {}
var _hover_category := ""
var _frame := 0
var _web_open_callback: JavaScriptObject = null  ## must stay referenced or the browser drops the callback


func setup(e: WorldEditor) -> void:
	mount(e)


func mount(e: WorldEditor) -> void:
	if editor != null:
		return
	editor = e
	name = "BlackEditorShell"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = make_theme()
	_build()
	if get_parent() == null:
		(editor.get_node("Root") as Control).add_child(self)
	_adopt_legacy()
	resized.connect(_on_resized)
	if is_inside_tree():
		get_tree().node_added.connect(_on_node_added)
	else:
		tree_entered.connect(func(): get_tree().node_added.connect(_on_node_added), CONNECT_ONE_SHOT)
	_last_panel_hidden = editor.panel_hidden
	_on_resized()
	update_state()


# ------------------------------------------------------------------ public API
func canvas_rect() -> Rect2:
	return center.get_global_rect() if center != null else Rect2()


## True when a screen point lands on shell chrome (toolbar, sidebars, status, legacy panel), i.e. not the canvas.
func consume_canvas(point: Vector2) -> bool:
	for c: Control in _chrome():
		if c.is_visible_in_tree() and c.get_global_rect().has_point(point):
			return true
	return false


func set_left_open(on: bool) -> void:
	left_open = on
	_sync_panel_hidden()
	_apply_layout()


func set_right_open(on: bool) -> void:
	right_open = on
	if on:
		_right_auto_collapsed = false
	_sync_panel_hidden()
	_apply_layout()


func _sync_panel_hidden() -> void:
	if editor != null:
		editor.panel_hidden = not left_open and not right_open
		_last_panel_hidden = editor.panel_hidden


func set_legacy_open(on: bool) -> void:
	legacy_open = on
	_apply_layout()


func show_page(build: bool) -> void:
	if editor.build_page == null or editor.settings_page == null:
		return
	editor._show_page(build)
	if editor.tab_build_button != null:
		editor.tab_build_button.set_pressed_no_signal(build)
		editor.tab_settings_button.set_pressed_no_signal(not build)
	if not left_open:
		set_left_open(true)
	update_state()


func settings_shown() -> bool:
	return editor.settings_page != null and (editor.settings_page.get_parent() as Control).visible


## Read-only snapshot of the editor's own fields (the editor stays the single owner of all of them).
func editor_state() -> Dictionary:
	if editor == null:
		return {}
	var pid := editor.place_id
	var cam := editor._camera() if editor.is_inside_tree() else null
	var layer: Variant = editor.get("active_layer")
	return {
		"open": editor.open,
		"map_mode": editor.map_mode,
		"tool": editor.tool,
		"place_id": pid,
		"asset": str(PlacedObjects.def_of(pid).get("label", "")) if pid != "" else "",
		"category": PlacedObjects.type_of(pid) if pid != "" else "",
		"layer": str(layer) if layer != null else "",
		"selected_id": str(editor.selected.get("id", "")),
		"selection_count": editor.selection.size(),
		"brush": editor.brush,
		"shape": editor.shape,
		"snap": editor.snap,
		"grid": editor.show_grid,
		"zoom": cam.zoom.x if cam != null else 1.0,
		"can_undo": editor.placed.can_undo(),
		"can_redo": editor.placed.can_redo(),
		"object_count": editor.placed.objects.size(),
		"clear_armed": editor._clear_armed,
		"page": "settings" if settings_shown() else "build",
		"left_open": left_open,
		"right_open": right_open,
		"legacy_open": legacy_open,
	}


## Called by the WorldEditor every frame.
func update_state() -> void:
	if editor == null:
		return
	_frame += 1
	_flush_skin_queue()
	if editor.panel_hidden != _last_panel_hidden:  # the editor's H key: hide / show the sidebars
		_last_panel_hidden = editor.panel_hidden
		left_open = not editor.panel_hidden
		right_open = not editor.panel_hidden
		_apply_layout()
	_enforce_legacy()
	var placed := editor.placed
	(toolbar_buttons["undo"] as Button).disabled = not placed.can_undo()
	(toolbar_buttons["redo"] as Button).disabled = not placed.can_redo()
	(toolbar_buttons["new"] as Button).text = "SURE?" if editor._clear_armed else "NEW"
	(toolbar_buttons["grid"] as Button).set_pressed_no_signal(editor.show_grid)
	(toolbar_buttons["snap"] as Button).set_pressed_no_signal(editor.snap > 0)
	(toolbar_buttons["snap"] as Button).text = "SNAP %d" % editor.snap if editor.snap > 0 else "SNAP OFF"
	var settings := settings_shown()
	(page_buttons["build"] as Button).set_pressed_no_signal(not settings)
	(page_buttons["settings"] as Button).set_pressed_no_signal(settings)
	if legacy_build_scroll != null:
		legacy_build_scroll.visible = not settings and (legacy_open or editor.black_assets == null)
	if editor.black_assets != null:
		editor.black_assets.visible = not settings
	if editor.inspector != null:
		_no_selection.visible = editor.selected.is_empty() and editor.selection.is_empty()
	for content: Control in _sections:
		var has := content.get_child_count() > 0
		(_sections[content] as Control).visible = has
		content.visible = has
	_update_status()


# ------------------------------------------------------------------ toolbar actions
func new_layout() -> void:
	editor._clear_pressed()
	update_state()


func save() -> bool:
	return editor.save_now()


func undo() -> void:
	editor.undo()


func redo() -> void:
	editor.redo()


func toggle_grid() -> void:
	editor.show_grid = not editor.show_grid
	if editor._grid_button != null:
		editor._grid_button.set_pressed_no_signal(editor.show_grid)
	editor._refresh()


func toggle_snap() -> void:
	if editor.snap > 0:
		_last_snap = editor.snap
		editor.snap = 0
	else:
		editor.snap = _last_snap if _last_snap > 0 else WorldEditor.SNAPS[0]
	editor._refresh()


static func playtest_supported() -> bool:
	return OS.has_feature("web") or OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


## Desktop playtest command: the same executable without the map-editor flag (run from the Godot editor binary,
## it also needs --path to find this project).
static func native_playtest_command() -> Dictionary:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")])
	return {"exe": OS.get_executable_path(), "args": args}


func playtest() -> bool:
	if not playtest_supported():
		editor._flash("Playtest is not supported on this platform")
		return false
	if not editor.save_now():
		return false
	if OS.has_feature("web"):
		return MapEditorMode.open_page("index.html")
	var cmd := native_playtest_command()
	var pid := OS.create_process(str(cmd.exe), cmd.args)
	editor._flash("PLAYTEST started" if pid > 0 else "PLAYTEST FAILED: could not start the game")
	return pid > 0


# ------------------------------------------------------------------ open a layout file
func open_layout() -> void:
	if OS.has_feature("web"):
		_open_web()
		return
	if file_dialog == null:
		file_dialog = FileDialog.new()
		file_dialog.name = "OpenLayoutDialog"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = PackedStringArray(["*.json ; Layout JSON"])
		file_dialog.use_native_dialog = true
		file_dialog.title = "Open layout"
		file_dialog.file_selected.connect(open_layout_file)
		add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)


func open_layout_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		editor._flash("OPEN FAILED: file not found")
		return false
	return open_layout_text(FileAccess.get_file_as_string(path), path.get_file())


func _open_web() -> void:
	if _web_open_callback == null:
		_web_open_callback = JavaScriptBridge.create_callback(_on_web_file)
		JavaScriptBridge.get_interface("window")[WEB_OPEN_HOOK] = _web_open_callback
	JavaScriptBridge.eval("(function(){var i=document.createElement('input');i.type='file';i.accept='.json,application/json';i.style.display='none';document.body.appendChild(i);i.addEventListener('change',function(){var f=i.files&&i.files[0];i.remove();if(!f){return;}var r=new FileReader();r.onload=function(){window." + WEB_OPEN_HOOK + "(String(r.result),f.name)};r.onerror=function(){window." + WEB_OPEN_HOOK + "('',f.name)};r.readAsText(f)});i.click()})()", true)


func _on_web_file(args: Array) -> void:
	var text := str(args[0]) if args.size() > 0 else ""
	var file_name := str(args[1]) if args.size() > 1 else "layout"
	open_layout_text(text, file_name)


## Checks a layout file before anything is cleared: a JSON object with a non-empty "items" list holding at least
## one entry with a known id and numeric x / y. PlacedObjects.load_dict still does the real per-item filtering.
static func parse_layout(text: String) -> Dictionary:
	var parser := JSON.new()
	if text.strip_edges().is_empty() or parser.parse(text) != OK:
		return {"ok": false, "error": "not valid JSON"}
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "not a layout object"}
	var items: Variant = (data as Dictionary).get("items")
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		return {"ok": false, "error": "no items list"}
	var valid := 0
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY or PlacedObjects.def_of(str((item as Dictionary).get("id", ""))).is_empty():
			continue
		var x: Variant = (item as Dictionary).get("x")
		var y: Variant = (item as Dictionary).get("y")
		if typeof(x) in [TYPE_FLOAT, TYPE_INT] and typeof(y) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(x)) and is_finite(float(y)):
			valid += 1
	if valid == 0:
		return {"ok": false, "error": "no usable items"}
	return {"ok": true, "data": data, "valid": valid, "total": (items as Array).size()}


## Replaces the level with a validated layout via PlacedObjects.load_dict (which, as everywhere else, resets the
## undo history). A malformed file is refused and the current level is left untouched.
func open_layout_text(text: String, source := "layout") -> bool:
	var parsed := parse_layout(text)
	if not parsed.ok:
		editor._flash("OPEN REFUSED (%s): %s" % [source, str(parsed.error)])
		return false
	var made := editor.placed.load_dict(parsed.data)
	editor.selected = {}
	editor.selection = []
	editor.dragging = false
	if editor.placed.autosave:
		editor.placed.save()
	editor._flash("OPENED %s: %d objects (%d skipped)" % [source, made, int(parsed.total) - made])
	editor._refresh()
	return true


# ------------------------------------------------------------------ build
func _build() -> void:
	center = Control.new()
	center.name = "Canvas"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.custom_minimum_size = Vector2.ZERO
	add_child(center)

	toolbar_panel = _chrome_panel("Toolbar", BG)
	toolbar = HBoxContainer.new()
	toolbar.name = "ToolbarRow"
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_panel.add_child(toolbar)
	var title := Label.new()
	title.text = "SHINOBI RUSH  MAP EDITOR"
	title.add_theme_font_size_override("font_size", 13)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(title)
	_toolbar_gap()
	_tool_button("new", "NEW", "Clear the level (press twice). Ctrl+Z undoes it.", new_layout)
	_tool_button("open", "OPEN", "Open a layout .json file (replaces the level, resets undo history)", open_layout)
	_tool_button("save", "SAVE", "Save the layout (Ctrl+S)", save)
	_toolbar_gap()
	_tool_button("undo", "UNDO", "Undo (Ctrl+Z)", undo)
	_tool_button("redo", "REDO", "Redo (Ctrl+Y or Ctrl+Shift+Z)", redo)
	_toolbar_gap()
	var play := _tool_button("playtest", "PLAYTEST", "Save, then open the game in a new tab" if OS.has_feature("web") else "Save, then launch the game in a new window", playtest)
	if not playtest_supported():
		play.disabled = true
		play.tooltip_text = "Playtest is not supported on this platform"
	_toolbar_gap()
	_tool_button("grid", "GRID", "Show the floor grid", toggle_grid).toggle_mode = true
	_tool_button("snap", "SNAP", "Snap placement to the grid", toggle_snap).toggle_mode = true
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.add_child(spacer)
	view_menu = MenuButton.new()
	view_menu.name = "ViewMenu"
	view_menu.text = "VIEW"
	view_menu.flat = false
	view_menu.focus_mode = Control.FOCUS_NONE
	view_menu.custom_minimum_size = Vector2(64, 32)
	view_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pm := view_menu.get_popup()
	pm.add_check_item("Left panel", VIEW_LEFT)
	pm.add_check_item("Right panel", VIEW_RIGHT)
	pm.add_check_item("Legacy controls", VIEW_LEGACY)
	pm.add_separator()
	pm.add_check_item("Collision overlay", VIEW_COLLISION)
	pm.add_check_item("Lighting overlay", VIEW_LIGHTING)
	pm.add_check_item("Navigation overlay", VIEW_NAVIGATION)
	pm.add_separator()
	pm.add_radio_check_item("Build page", VIEW_BUILD)
	pm.add_radio_check_item("Settings", VIEW_SETTINGS)
	pm.id_pressed.connect(_on_view_id)
	pm.about_to_popup.connect(_sync_view_menu)
	toolbar.add_child(view_menu)
	toolbar_buttons["view"] = view_menu

	left_panel = _chrome_panel("LeftPanel", PANEL)
	left_content = VBoxContainer.new()
	left_content.name = "LeftContent"
	left_content.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_content)
	var pages := HBoxContainer.new()
	pages.name = "PageTabs"
	pages.add_theme_constant_override("separation", 4)
	left_content.add_child(pages)
	var group := ButtonGroup.new()
	for key: String in ["build", "settings"]:
		var b := Button.new()
		b.text = "ASSETS" if key == "build" else "SETTINGS"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_page.bind(key == "build"))
		pages.add_child(b)
		page_buttons[key] = b
	asset_content = _content(left_content, "AssetContent", "", true)

	right_panel = _chrome_panel("RightPanel", PANEL)
	right_content = VBoxContainer.new()
	right_content.name = "RightContent"
	right_content.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_content)
	_header(right_content, "PROPERTIES")
	var props_scroll := ScrollContainer.new()
	props_scroll.name = "PropertiesScroll"
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_child(props_scroll)
	properties_content = VBoxContainer.new()
	properties_content.name = "PropertiesContent"
	properties_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties_content.add_theme_constant_override("separation", 6)
	props_scroll.add_child(properties_content)
	_no_selection = Label.new()
	_no_selection.text = "No selection"
	_no_selection.add_theme_color_override("font_color", SECONDARY)
	properties_content.add_child(_no_selection)
	minimap_content = _content(right_content, "MinimapContent", "MINIMAP", false)

	status_panel = _chrome_panel("StatusBar", BG)
	dock = HBoxContainer.new()
	dock.name = "StatusRow"
	dock.add_theme_constant_override("separation", 14)
	status_panel.add_child(dock)
	for key: String in ["tool", "asset", "layer", "coords", "zoom", "grid", "snap", "message"]:
		var l := Label.new()
		l.name = "Status_" + key
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", TEXT if key == "message" else SECONDARY)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if key == "message":
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
		dock.add_child(l)
		status_labels[key] = l


func _chrome_panel(node_name: String, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = node_name
	p.mouse_filter = Control.MOUSE_FILTER_STOP  # blank sidebar / bar space never reaches the canvas
	p.mouse_force_pass_scroll_events = false
	var sb := _sbox(bg, BORDER, 0, 0)
	sb.set_content_margin_all(8)
	match node_name:
		"Toolbar":
			sb.border_width_bottom = 1
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
		"StatusBar":
			sb.border_width_top = 1
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
		"LeftPanel":
			sb.border_width_right = 1
		"RightPanel":
			sb.border_width_left = 1
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _header(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", SECONDARY)
	parent.add_child(l)
	return l


func _content(parent: Control, node_name: String, title: String, expand: bool) -> VBoxContainer:
	var head: Label = _header(parent, title) if title != "" else null
	var box := VBoxContainer.new()
	box.name = node_name
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand:
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	if head != null:
		_sections[box] = head
	return box


func _tool_button(key: String, text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "Toolbar_" + key
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	toolbar.add_child(b)
	toolbar_buttons[key] = b
	return b


func _toolbar_gap() -> void:
	var s := VSeparator.new()
	var line := StyleBoxLine.new()
	line.color = BORDER
	line.vertical = true
	line.thickness = 1
	s.add_theme_stylebox_override("separator", line)
	toolbar.add_child(s)


# ------------------------------------------------------------------ legacy adoption
func _adopt_legacy() -> void:
	if editor.build_page != null:
		legacy_build_scroll = ScrollContainer.new()
		legacy_build_scroll.name = "LegacyBuildScroll"
		legacy_build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		legacy_build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		asset_content.add_child(legacy_build_scroll)
		editor.build_page.get_parent().remove_child(editor.build_page)
		editor.build_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor.build_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		legacy_build_scroll.add_child(editor.build_page)
		_skin_roots.append(editor.build_page)
	else:
		legacy_open = true  # no map-editor build page to adopt: the legacy panel stays the editor's only UI
	if editor.settings_page != null:
		var settings_scroll := editor.settings_page.get_parent() as Control
		settings_scroll.get_parent().remove_child(settings_scroll)
		asset_content.add_child(settings_scroll)
		settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_skin_roots.append(settings_scroll)
	else:
		(page_buttons["settings"] as Button).disabled = true
	if editor.inspector != null:
		editor.inspector.get_parent().remove_child(editor.inspector)
		properties_content.add_child(editor.inspector)
		_skin_roots.append(editor.inspector)
	if editor.panel != null:
		_skin_roots.append(editor.panel)
	for r: Node in _skin_roots:
		skin_tree(r)


## The legacy panel stays alive (publish / download / reset live there) but only shows when asked for, sitting
## inside the canvas so the sidebars never cover it.
func _enforce_legacy() -> void:
	if editor.panel == null:
		return
	var show := legacy_open and editor.open
	if editor.panel.visible != show:
		editor.panel.visible = show
	if editor.map_mode and editor.tab != null and editor.tab.visible:
		editor.tab.visible = false


# ------------------------------------------------------------------ layout
func _on_resized() -> void:
	var w := size.x
	var compact := w < COMPACT_BELOW
	left_width = LEFT_W_COMPACT if compact else LEFT_W
	right_width = RIGHT_W_COMPACT if compact else RIGHT_W
	var narrow := w < NARROW_BELOW
	if narrow and not _was_narrow and right_open:
		right_open = false
		_right_auto_collapsed = true
	elif not narrow and _was_narrow and _right_auto_collapsed and not right_open:
		right_open = true
		_right_auto_collapsed = false
	_was_narrow = narrow
	_apply_layout()


func _apply_layout() -> void:
	var lw := left_width if left_open else 0.0
	var rw := right_width if right_open else 0.0
	_place(toolbar_panel, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, TOOLBAR_H))
	_place(status_panel, Vector4(0, 1, 1, 1), Vector4(0, -STATUS_H, 0, 0))
	_place(left_panel, Vector4(0, 0, 0, 1), Vector4(0, TOOLBAR_H, lw, -STATUS_H))
	_place(right_panel, Vector4(1, 0, 1, 1), Vector4(-rw, TOOLBAR_H, 0, -STATUS_H))
	_place(center, Vector4(0, 0, 1, 1), Vector4(lw, TOOLBAR_H, -rw, -STATUS_H))
	left_panel.visible = left_open
	right_panel.visible = right_open
	if editor != null and editor.panel != null and legacy_open:
		editor.panel.offset_left = -(rw + WorldEditor.PANEL_W_MAP)
		editor.panel.offset_right = -rw
		editor.panel.offset_top = TOOLBAR_H + 8
		editor.panel.offset_bottom = -STATUS_H - 8
	if editor != null:
		_enforce_legacy()


## anchors / offsets as (left, top, right, bottom)
static func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _chrome() -> Array[Control]:
	var out: Array[Control] = [toolbar_panel, left_panel, right_panel, status_panel]
	if editor != null and editor.panel != null:
		out.append(editor.panel)
	return out


# ------------------------------------------------------------------ view menu
func _sync_view_menu() -> void:
	var pm := view_menu.get_popup()
	pm.set_item_checked(pm.get_item_index(VIEW_LEFT), left_open)
	pm.set_item_checked(pm.get_item_index(VIEW_RIGHT), right_open)
	pm.set_item_checked(pm.get_item_index(VIEW_LEGACY), legacy_open)
	pm.set_item_checked(pm.get_item_index(VIEW_COLLISION), editor.show_collision_overlay)
	pm.set_item_checked(pm.get_item_index(VIEW_LIGHTING), editor.show_lighting_overlay)
	pm.set_item_checked(pm.get_item_index(VIEW_NAVIGATION), editor.show_navigation_overlay)
	var has_pages := editor.settings_page != null and editor.build_page != null
	pm.set_item_disabled(pm.get_item_index(VIEW_BUILD), not has_pages)
	pm.set_item_disabled(pm.get_item_index(VIEW_SETTINGS), not has_pages)
	pm.set_item_checked(pm.get_item_index(VIEW_BUILD), has_pages and not settings_shown())
	pm.set_item_checked(pm.get_item_index(VIEW_SETTINGS), settings_shown())


func _on_view_id(id: int) -> void:
	match id:
		VIEW_LEFT:
			set_left_open(not left_open)
		VIEW_RIGHT:
			set_right_open(not right_open)
		VIEW_LEGACY:
			set_legacy_open(not legacy_open)
		VIEW_COLLISION:
			editor.show_collision_overlay = not editor.show_collision_overlay
			editor.overlay.queue_redraw()
		VIEW_LIGHTING:
			editor.show_lighting_overlay = not editor.show_lighting_overlay
			editor.overlay.queue_redraw()
		VIEW_NAVIGATION:
			editor.show_navigation_overlay = not editor.show_navigation_overlay
			editor.overlay.queue_redraw()
		VIEW_BUILD:
			show_page(true)
		VIEW_SETTINGS:
			show_page(false)
	_sync_view_menu()


# ------------------------------------------------------------------ status bar
func _update_status() -> void:
	var s := editor_state()
	var category := str(s.category)
	var mouse := get_viewport().get_mouse_position() if is_inside_tree() else Vector2.INF
	var over := canvas_rect().has_point(mouse)
	var world := Vector2.ZERO
	if over and editor.overlay != null and editor.overlay.is_inside_tree():
		world = editor._mouse_world()
		if category == "" and _frame % 6 == 0:
			var hit := editor.placed.hit_test(world)
			_hover_category = PlacedObjects.type_of(str(hit.id)) if not hit.is_empty() else ""
	var layer := str(s.layer)
	if category == "":
		category = _hover_category
	(status_labels["tool"] as Label).text = "TOOL  " + str(s.tool).to_upper()
	(status_labels["asset"] as Label).text = "ASSET  " + (str(s.asset) if str(s.asset) != "" else "-")
	(status_labels["layer"] as Label).text = "LAYER  %s (%s)" % [layer if layer != "" else "-", category if category != "" else "-"]
	if over:
		var cell := WorldEditor.iso_cell_center(world)
		(status_labels["coords"] as Label).text = "X %d  Y %d   CELL %d,%d" % [int(world.x), int(world.y), int(cell.x / 36.0), int(cell.y / 18.0)]
	else:
		(status_labels["coords"] as Label).text = "X -  Y -"
	(status_labels["zoom"] as Label).text = "ZOOM %d%%" % int(round(float(s.zoom) * 100.0))
	(status_labels["grid"] as Label).text = "GRID ON" if s.grid else "GRID OFF"
	(status_labels["snap"] as Label).text = "SNAP %d" % int(s.snap) if int(s.snap) > 0 else "SNAP OFF"
	(status_labels["message"] as Label).text = editor.status.text if editor.status != null else ""


# ------------------------------------------------------------------ theme + legacy skin
static func _sbox(bg: Color, border := BORDER, bw := 1, radius := 4) -> StyleBoxFlat:
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


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	for type: String in ["Button", "MenuButton", "OptionButton"]:
		t.set_stylebox("normal", type, _sbox(RAISED))
		t.set_stylebox("hover", type, _sbox(HOVER, Color("#3a3a3a")))
		t.set_stylebox("pressed", type, _sbox(ACTIVE, TEXT))
		t.set_stylebox("hover_pressed", type, _sbox(ACTIVE, TEXT))
		t.set_stylebox("disabled", type, _sbox(BG, Color("#1c1c1c")))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, type, TEXT)
		t.set_color("font_disabled_color", type, DISABLED)
	for type: String in ["CheckBox", "CheckButton"]:
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, type, TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "LineEdit", _sbox(BG))
	t.set_stylebox("focus", "LineEdit", _sbox(BG, SECONDARY))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PopupMenu", _sbox(PANEL))
	t.set_stylebox("hover", "PopupMenu", _sbox(ACTIVE, ACTIVE, 0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_color("font_disabled_color", "PopupMenu", DISABLED)
	t.set_stylebox("panel", "TooltipPanel", _sbox(PANEL))
	t.set_color("font_color", "TooltipLabel", TEXT)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _sbox(BG, BG, 0))
		t.set_stylebox("grabber", bar, _sbox(Color("#333333"), BORDER, 0))
		t.set_stylebox("grabber_highlight", bar, _sbox(Color("#4a4a4a"), BORDER, 0))
		t.set_stylebox("grabber_pressed", bar, _sbox(Color("#5a5a5a"), BORDER, 0))
	return t


## Orange / yellow / cyan UI accents from the legacy skin get neutralised; red (danger) is kept.
static func is_accent(c: Color) -> bool:
	return c.a > 0.3 and c.s > 0.35 and ((c.h >= 0.02 and c.h <= 0.18) or (c.h >= 0.44 and c.h <= 0.56))


static func _restyle(c: Control, key: String, s: StyleBoxFlat) -> void:
	var old := c.get_theme_stylebox(key) if c.has_theme_stylebox_override(key) else null
	if old != null:
		s.content_margin_left = old.content_margin_left
		s.content_margin_right = old.content_margin_right
		s.content_margin_top = old.content_margin_top
		s.content_margin_bottom = old.content_margin_bottom
	c.add_theme_stylebox_override(key, s)


## Neutral black skin over a legacy subtree. Textures (palette thumbnails, world art) are left untouched.
static func skin_tree(n: Node) -> void:
	skin_node(n)
	for child in n.get_children():
		skin_tree(child)


static func skin_node(n: Node) -> void:
	if n is CheckBox or n is CheckButton:
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			(n as Control).add_theme_color_override(k, TEXT)
		(n as Button).clip_text = true
	elif n is Button:
		var b := n as Button
		var danger := b.has_theme_color_override("font_color") and b.get_theme_color("font_color").is_equal_approx(LEGACY_DANGER_TEXT)
		_restyle(b, "normal", _sbox(RAISED))
		_restyle(b, "hover", _sbox(HOVER, Color("#3a3a3a")))
		_restyle(b, "pressed", _sbox(ACTIVE, TEXT))
		_restyle(b, "hover_pressed", _sbox(ACTIVE, TEXT))
		_restyle(b, "disabled", _sbox(BG, Color("#1c1c1c")))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var fc := DANGER_TEXT if danger else TEXT
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, fc)
		b.add_theme_color_override("font_disabled_color", DISABLED)
		if b.icon == null:
			b.clip_text = true
	elif n is Label:
		var l := n as Label
		var c: Color = l.get_theme_color("font_color") if l.has_theme_color_override("font_color") else TEXT
		var red := c.s > 0.4 and (c.h < 0.02 or c.h > 0.95)
		if not red:
			l.add_theme_color_override("font_color", SECONDARY if c.a < 0.9 else TEXT)
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
	elif n is ColorRect:
		var r := n as ColorRect
		if is_accent(r.color) or r.color.is_equal_approx(WorldEditor.EDGE):
			r.color = BORDER
	elif n is LineEdit:
		_restyle(n as Control, "normal", _sbox(BG))
		_restyle(n as Control, "focus", _sbox(BG, SECONDARY))
		(n as LineEdit).add_theme_color_override("font_color", TEXT)
	elif n is Slider:
		(n as Control).add_theme_stylebox_override("slider", _sbox(ACTIVE, BORDER, 0, 2))
		(n as Control).add_theme_stylebox_override("grabber_area", _sbox(SECONDARY, BORDER, 0, 2))
		(n as Control).add_theme_stylebox_override("grabber_area_highlight", _sbox(TEXT, BORDER, 0, 2))
	elif n is ScrollBar:
		var sb := n as ScrollBar
		sb.add_theme_stylebox_override("scroll", _sbox(BG, BG, 0))
		sb.add_theme_stylebox_override("grabber", _sbox(Color("#333333"), BORDER, 0))
		sb.add_theme_stylebox_override("grabber_highlight", _sbox(Color("#4a4a4a"), BORDER, 0))
		sb.add_theme_stylebox_override("grabber_pressed", _sbox(Color("#5a5a5a"), BORDER, 0))
	elif n is PanelContainer:
		var root_panel := n.is_in_group("world_builder_ui")
		_restyle(n as Control, "panel", _sbox(BG if root_panel else PANEL))


func _on_node_added(n: Node) -> void:
	for r: Node in _skin_roots:
		if is_instance_valid(r) and (r == n or r.is_ancestor_of(n)):
			_skin_queue[n] = true
			return


## Skinned on the next update so overrides the editor applies right after add_child are replaced too.
func _flush_skin_queue() -> void:
	if _skin_queue.is_empty():
		return
	var nodes := _skin_queue.keys()
	_skin_queue.clear()
	for n: Variant in nodes:
		if is_instance_valid(n):
			skin_node(n as Node)
