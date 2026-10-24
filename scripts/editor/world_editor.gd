class_name WorldEditor
extends CanvasLayer
## World Builder: a small collapsible tools panel on the RIGHT edge for placing trees, walls and other built
## objects (PlacedObjects.CATALOG) anywhere in the arena. The BUILD tab opens it (no hotkey).
##   Pick an item in the palette, click the world to place it (right-click or Select to stop).
##   Select / Move: click an object to pick it, drag to move it, Delete removes it.   Erase: click objects to remove them.
## The layout autosaves (user://world_builder_layout.json). While the panel is hidden nothing is editable.
const PANEL_W := 236.0
const ACCENT := Color("#FF6B00")
const SNAPS: Array[int] = [30, 15, 0]

var arena: TrainingArena
var placed: PlacedObjects
var open := false
var tool := "select"  ## "select" | "erase" | "place" | "paint" | "pan"
const BRUSHES: Array[int] = [1, 3, 5]
var brush := 1  ## paint tool: the brush is a brush x brush block of floor cells
var _stroke := false
var _stroke_changed := false
var _last_cell := Vector2(INF, INF)
var _paint_button: Button = null
var brush_button: Button = null
var _panning := false
var _camera_free := false
var _pan_camera_mode := Node.PROCESS_MODE_INHERIT
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
var grid_layer: Node2D
var _tool_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}
var _filter_buttons: Dictionary = {}
var _category_sections: Dictionary = {}
var palette_scroll: ScrollContainer
var _clear_armed := false
var _js_state: JavaScriptObject
var _hud_buttons: Dictionary = {}
var hud_snap_button: Button = null
## Builder guides (Settings tab), all OFF by default: a white floor grid and, per object type, a box that
## bounds exactly the art. The selected object always shows its own box so you can see what you picked.
const DIM_TYPES: Array[String] = ["Trees", "Walls & blocks", "Temple walls", "Fences", "Grass", "Tall grass", "Ground / paths", "Temple ground"]
var show_grid := false
var show_dims: Dictionary = {}  ## type name -> bool
var _settings_rows_added := false
var _grid_button: Button = null
var _dim_buttons: Dictionary = {}


class Overlay extends Node2D:
	var editor: WorldEditor
	func _init(e: WorldEditor) -> void:
		editor = e
		z_index = 200
		name = "WorldEditorOverlay"
		process_mode = Node.PROCESS_MODE_ALWAYS  # keeps drawing the cursor/outlines while the game is paused
	func _process(_d: float) -> void:
		visible = editor.open
		if visible:
			queue_redraw()
	func _draw() -> void:
		editor.draw_overlay(self)


## Floor grid layer: sits on the ground (same z_index as Ground, added after it) so walls, trees and every
## other y-sorted object draw OVER the lines and hide the cells they cover.
class GridLayer extends Node2D:
	var editor: WorldEditor
	func _init(e: WorldEditor) -> void:
		editor = e
		z_index = -1
		name = "WorldEditorGrid"
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_d: float) -> void:
		visible = editor.show_grid
		if visible:
			queue_redraw()
	func _draw() -> void:
		if editor.arena != null:
			editor._draw_floor_grid(self)


func setup(a: TrainingArena, p: PlacedObjects) -> void:
	arena = a
	placed = p


func _ready() -> void:
	layer = 7
	name = "WorldEditor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Overlay.new(self)
	arena.add_child(overlay)
	grid_layer = GridLayer.new(self)
	arena.add_child(grid_layer)
	_build_ui()
	set_open(false)
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		_js_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__EDITOR_STATE__ = _js_state
		if "editor=1" in query:
			set_open(true)


func _process(_d: float) -> void:
	var hud := hud_bar()
	if hud != null and hud.edit_mode != open:
		hud.set_edit_mode(open)
	if not _settings_rows_added and SettingsPanel.instance() != null:
		_add_settings_rows(SettingsPanel.instance())
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
	_set_camera_free(v)
	panel.visible = v
	tab.visible = not v
	var hud := hud_bar()
	if hud != null:
		hud.set_edit_mode(v)
	if not v:
		dragging = false
		selected = {}
		_clear_armed = false
		_reset_armed = false
	_refresh()


func set_tool(t: String, id := "") -> void:
	tool = t
	if t == "paint":
		if id != "":
			place_id = id
		if place_id == "" or PlacedObjects.def_of(place_id).kind not in ["ground", "grass"]:
			place_id = "temple_floor_center"  # nothing tile-like chosen yet: start with the stone floor
	else:
		place_id = id if t == "place" else ""
	if t != "select":
		selected = {}
	_refresh()


func snapped_pos(p: Vector2) -> Vector2:
	if snap > 0 and _grass_tool():
		return iso_cell_center(p)
	if snap > 0 and _wall_tool():
		return PlacedObjects.iso_vertex(p)  # wall kit pieces sit on floor-diamond vertices so runs join
	return p if snap <= 0 else (p / float(snap)).round() * float(snap)

## Centre of the floor-grid diamond (72 x 36 tiles, centres at (36k, 18m) with k and m of equal parity) nearest to p.
static func iso_cell_center(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	var k0 := int(floor(p.x / 36.0))
	var m0 := int(floor(p.y / 18.0))
	for k in [k0, k0 + 1]:
		for m in [m0, m0 + 1]:
			if posmod(k - m, 2) != 0:
				continue
			var c := Vector2(36.0 * k, 18.0 * m)
			var d := c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


func _wall_tool() -> bool:
	var id := place_id if tool in ["place", "paint"] else str(selected.get("id", ""))
	return id != "" and PlacedObjects.def_of(id).kind == "wall"


func _grass_tool() -> bool:
	var id := place_id if tool in ["place", "paint"] else str(selected.get("id", ""))
	return id != "" and PlacedObjects.def_of(id).kind in ["grass", "ground"]


func _mouse_world() -> Vector2:
	return overlay.get_global_mouse_position()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if open and event.keycode == KEY_S and event.ctrl_pressed:
			save_now()
			get_viewport().set_input_as_handled()
			return
		if open and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and hud_bar() != null and hud_bar().selected_element != "":
			var step := 10.0 if event.shift_pressed else 1.0
			var dir := Vector2(float(event.keycode == KEY_RIGHT) - float(event.keycode == KEY_LEFT), float(event.keycode == KEY_DOWN) - float(event.keycode == KEY_UP))
			hud_bar().move_element(hud_bar().selected_element, dir * step)
			hud_bar().save_layout()
			get_viewport().set_input_as_handled()
			return
		if open and (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and not selected.is_empty():
			delete_selected()
			get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event is InputEventMouseMotion and _panning:
		pan_by((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and tool == "pan":
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not press_hud(get_viewport().get_mouse_position()):
					press(_mouse_world())
			elif hud_bar() != null and hud_bar().dragging_element:
				release_hud()
			elif _stroke:
				end_stroke()
			else:
				release()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			set_tool("select")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and hud_bar() != null and hud_bar().dragging_element:
		hud_bar().drag_at(get_viewport().get_mouse_position(), not Input.is_key_pressed(KEY_SHIFT))
	elif event is InputEventMouseMotion and _stroke:
		paint_to(_mouse_world())
	elif event is InputEventMouseMotion and dragging:
		drag_to(_mouse_world())


func _camera() -> Camera2D:
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	return p.camera if p != null else null


## While the builder is open the camera keeps running through a pause, so you can pan and place on a frozen world.
func _set_camera_free(on: bool) -> void:
	var cam := _camera()
	if cam == null:
		return
	if on:
		if _camera_free:
			return
		_camera_free = true
		_pan_camera_mode = cam.process_mode
		cam.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		_camera_free = false
		cam.process_mode = _pan_camera_mode
		cam.offset = Vector2.ZERO
		_panning = false


## Drag the view by a screen-space delta (works while the game is paused).
func pan_by(screen_delta: Vector2) -> void:
	var cam := _camera()
	if cam != null:
		cam.offset -= screen_delta / cam.zoom
		cam.force_update_scroll()


## The player's HUD (HealthBar canvas layer), or null when there is no player yet.
func hud_bar() -> HealthBar:
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return p.get_node_or_null("HealthBar") as HealthBar if p != null else null


## Builder, select tool: a click on a HUD piece (bars, avatar, pips, ability slots) picks it up instead of a world object.
func press_hud(screen: Vector2) -> bool:
	var hud := hud_bar()
	if not open or tool != "select" or hud == null:
		return false
	if not hud.press_at(screen):
		return false
	selected = {}
	_refresh()
	return true


func release_hud() -> void:
	var hud := hud_bar()
	if hud != null:
		hud.release_drag()
	_refresh()


func select_hud(id: String) -> void:
	var hud := hud_bar()
	if hud == null:
		return
	set_tool("select")
	hud.select_element("" if hud.selected_element == id else id)
	_flash("%s: drag it, or arrow keys (Shift = 10px)" % HealthBar.ELEMENT_NAMES[id] if hud.selected_element == id else "HUD piece deselected")
	_refresh()


## Floor cells a brush stamped at `world` covers: a brush x brush block of 72x36 diamonds, centred on the cell under it.
func brush_cells(world: Vector2) -> Array[Vector2]:
	var c := iso_cell_center(world)
	var out: Array[Vector2] = []
	var r := (brush - 1) / 2
	for i in range(-r, r + 1):
		for j in range(-r, r + 1):
			out.append(c + Vector2(36.0, 18.0) * float(i) + Vector2(36.0, -18.0) * float(j))
	return out


## Stamp the brush at `world`; true if any tile changed.
func paint_at(world: Vector2) -> bool:
	var any := false
	for cell in brush_cells(world):
		if placed.paint_cell(place_id, cell):
			any = true
	if any:
		_stroke_changed = true
	return any


## Paint along the mouse path since the last sample so a fast drag leaves no gaps.
func paint_to(world: Vector2) -> void:
	var cell := iso_cell_center(world)
	if cell == _last_cell:
		return
	if _last_cell.is_finite():
		var from := _last_cell
		var steps := int(ceil(from.distance_to(cell) / 18.0))
		for s in range(1, steps + 1):
			paint_at(from.lerp(cell, float(s) / float(steps)))
	else:
		paint_at(world)
	_last_cell = cell


func end_stroke() -> void:
	if not _stroke:
		return
	_stroke = false
	_last_cell = Vector2(INF, INF)
	if _stroke_changed:
		_stroke_changed = false
		placed._changed()  # one nav rebuild + one save for the whole stroke
	_refresh()


func press(world: Vector2) -> void:
	match tool:
		"paint":
			_stroke = true
			_stroke_changed = false
			_last_cell = Vector2(INF, INF)
			paint_to(world)
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


## Repo-tracked file this writes to and commits -- a real file under version control (unlike
## PlacedObjects.SAVE_PATH, which is per-machine user:// data outside the repo entirely).
const REPO_LAYOUT_PATH := "res://data/world_layout.json"


## Pure interpretation of a `git commit` attempt's exit code/output text -- decides the user-facing
## outcome without running git, so every branch (ok, benign no-op, real failure) is covered by a CI
## test without ever executing a real git process. `done` means the whole publish is finished (no
## push needed); otherwise the caller proceeds to push.
static func _commit_outcome(code: int, output_text: String) -> Dictionary:
	if code == 0:
		return {"ok": true, "done": false, "message": ""}
	if output_text.contains("nothing to commit") or output_text.contains("nothing added"):
		return {"ok": true, "done": true, "message": "PUBLISH: no changes to publish"}
	return {"ok": false, "done": true, "message": "PUBLISH FAILED (commit): %s" % output_text.left(90)}


## Pure interpretation of a `git push` attempt's exit code/output text.
static func _push_outcome(code: int, output_text: String, object_count: int) -> Dictionary:
	if code != 0:
		return {"ok": false, "message": "PUBLISH FAILED (push): %s" % output_text.left(90)}
	return {"ok": true, "message": "PUBLISHED  %d objects -> GitHub" % object_count}


## Desktop/editor only (owner 2026-10-23: "save button needs to commit and push straight to github
## all new level changes"). Deliberately does NOT exist on Web (see the button that calls this,
## created only when `not OS.has_feature("web")`) -- OS.execute has no effect in a Web export anyway,
## and this must never be reachable from the publicly-playable browser build. Uses the machine's own
## already-configured git identity (SSH key / credential manager / `gh auth`) -- no token is ever
## read, stored, or embedded here or anywhere else in this project.
##
## Safety: `git add` is scoped to ONLY this one file (never `-A` or `.`), and the commit is further
## restricted to that same single pathspec (`git commit -- <path>`) even if something else happens
## to already be staged -- this can never sweep up or publish unrelated work-in-progress changes
## elsewhere in the repo. Does not force-push and does not attempt to bypass branch protection; a
## rejected push (e.g. a protected branch requiring a PR) is reported plainly, not retried.
func publish_to_github() -> bool:
	if OS.has_feature("web"):
		return false
	var abs_path := ProjectSettings.globalize_path(REPO_LAYOUT_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		_flash("PUBLISH FAILED (could not write %s)" % REPO_LAYOUT_PATH)
		return false
	f.store_string(placed.to_json_string())
	f.close()
	var repo_root := ProjectSettings.globalize_path("res://")
	var rel_path := REPO_LAYOUT_PATH.trim_prefix("res://")
	var out: Array = []
	OS.execute("git", ["-C", repo_root, "add", "--", rel_path], out, true)
	out.clear()
	var msg := "World Builder: publish live layout (%d objects)" % placed.objects.size()
	var commit_code := OS.execute("git", ["-C", repo_root, "commit", "-m", msg, "--", rel_path], out, true)
	var commit := _commit_outcome(commit_code, "\n".join(out))
	if commit.done:
		_flash(commit.message)
		return commit.ok
	out.clear()
	var push_code := OS.execute("git", ["-C", repo_root, "push"], out, true)
	var push := _push_outcome(push_code, "\n".join(out), placed.objects.size())
	_flash(push.message)
	return push.ok


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


static func _diamond(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -18), c + Vector2(36, 0), c + Vector2(0, 18), c + Vector2(-36, 0), c + Vector2(0, -18)])


# ------------------------------------------------------------------ overlay drawing
## Floor grid + one "dimensions" switch per object type, living in the Settings tab (default off).
func _add_settings_rows(sp: SettingsPanel) -> void:
	_settings_rows_added = true
	_grid_button = _settings_toggle("Floor grid (white)", Color("#DDDDDD"), func(on: bool) -> void: show_grid = on)
	sp.add_row(_grid_button)
	for t in DIM_TYPES:
		show_dims[t] = false
		var b := _settings_toggle("Dimensions: %s" % t, ACCENT, func(on: bool) -> void: show_dims[t] = on)
		_dim_buttons[t] = b
		sp.add_row(b)


func _settings_toggle(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	SettingsPanel.style_toggle(b, color)
	b.toggled.connect(cb)
	return b


func dims_on(type_name: String) -> bool:
	return bool(show_dims.get(type_name, false))


## White 72x36 floor lattice (the diamond tile grid the walls and grass snap to) across the whole arena.
func _draw_floor_grid(c: Node2D) -> void:
	var b: Rect2 = arena.bounds
	var col := Color(1, 1, 1, 0.38)
	for family in [1.0, -1.0]:
		# lines y = family * x / 2 + k * 18 with k odd pass through every diamond edge
		var k_lo := int(floor((b.position.y - family * b.end.x * 0.5) / 18.0)) - 1
		var k_hi := int(ceil((b.end.y - family * b.position.x * 0.5) / 18.0)) + 1
		if family < 0.0:
			k_lo = int(floor((b.position.y + b.position.x * 0.5) / 18.0)) - 1
			k_hi = int(ceil((b.end.y + b.end.x * 0.5) / 18.0)) + 1
		for k in range(k_lo, k_hi + 1):
			if posmod(k, 2) != 1:
				continue
			var cst := float(k) * 18.0
			var seg := _clip_line(b, family * 0.5, cst)
			if seg.size() == 2:
				c.draw_line(seg[0], seg[1], col, 1.0)


## Clip the line y = m*x + c to rect r; returns [] or [a, b].
static func _clip_line(r: Rect2, m: float, cst: float) -> Array:
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := m * x0 + cst
	var y1 := m * x1 + cst
	var lo := 0.0
	var hi := 1.0
	for t in [[y0, y1, r.position.y, r.end.y]]:
		var dy: float = t[1] - t[0]
		if absf(dy) < 0.0001:
			if t[0] < t[2] or t[0] > t[3]:
				return []
		else:
			var ta: float = (t[2] - t[0]) / dy
			var tb: float = (t[3] - t[0]) / dy
			lo = maxf(lo, minf(ta, tb))
			hi = minf(hi, maxf(ta, tb))
	if lo >= hi:
		return []
	return [Vector2(lerpf(x0, x1, lo), lerpf(y0, y1, lo)), Vector2(lerpf(x0, x1, hi), lerpf(y0, y1, hi))]


func draw_overlay(c: Node2D) -> void:
	if not open:
		return
	for o in placed.objects:
		if not placed.type_visible(o.id):
			continue
		var sel: bool = (o == selected)
		if sel:
			c.draw_rect(PlacedObjects.art_rect(o.id, o.pos), Color(1, 0.84, 0.2, 0.95), false, 3.0)
		elif dims_on(PlacedObjects.type_of(o.id)):
			c.draw_rect(PlacedObjects.art_rect(o.id, o.pos), Color(ACCENT, 0.7), false, 2.0)
	if tool == "erase" and get_viewport().gui_get_hovered_control() == null:
		var h := placed.hit_test(_mouse_world())
		if not h.is_empty():
			c.draw_rect(PlacedObjects.art_rect(h.id, h.pos), Color(1, 0.2, 0.2, 0.9), false, 3.0)
	if tool == "paint" and place_id != "" and get_viewport().gui_get_hovered_control() == null:
		var ptex: Texture2D = PlacedObjects.art_texture(place_id, Vector2.ZERO)[0]
		for cell in brush_cells(_mouse_world()):
			if ptex != null:
				c.draw_texture(ptex, cell - Vector2(36, 18), Color(1, 1, 1, 0.65))
			c.draw_polyline(_diamond(cell), Color(ACCENT, 0.9), 2.0)
	if tool == "place" and place_id != "" and get_viewport().gui_get_hovered_control() == null:
		var pos := snapped_pos(_mouse_world())
		var ok := placed.can_place(place_id, pos)
		# The ghost is the art itself: normal tint when the spot is legal, red when it is not. No separate
		# footprint square (it never covered the art and did not guide placement).
		var at := PlacedObjects.art_texture(place_id, pos)
		var gtex: Texture2D = at[0]
		var gcol := Color(1, 1, 1, 0.6) if ok else Color(1, 0.4, 0.4, 0.6)
		if gtex != null:
			c.draw_texture(gtex, at[1], gcol)
		else:
			c.draw_rect(PlacedObjects.hit_rect(place_id, pos), Color(gcol, 0.3))
		if dims_on(PlacedObjects.type_of(place_id)) or not ok:
			c.draw_rect(PlacedObjects.art_rect(place_id, pos), Color(ACCENT, 0.9) if ok else Color(1, 0.3, 0.3, 0.95), false, 2.0)


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
	tab.tooltip_text = "World Builder"
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
	sub.text = "SHINOBI RUSH"
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
	_tool_buttons["paint"] = _toggle(tools, "PAINT", func(): set_tool("paint"))
	_tool_buttons["pan"] = _toggle(tools, "PAN", func(): set_tool("pan"))
	_paint_button = _tool_buttons["paint"]
	brush_button = _toggle(outer, "BRUSH  1 x 1  (paint: drag to lay many tiles)", func(): cycle_brush())

	# Palette filters: hide/show the option cards by type; the world itself is untouched.
	var filters := GridContainer.new()
	filters.columns = 2
	outer.add_child(filters)
	var filter_cats: Array = PlacedObjects.CATEGORIES.duplicate()
	filter_cats.append(["HUD layout", []])  # the HUD piece controls are a section like the others (hidden until ticked)
	for category: Array in filter_cats:
		var name := str(category[0])
		var check := CheckBox.new()
		check.text = "Walls" if name == "Walls & blocks" else name
		check.tooltip_text = "Show/hide the " + name.to_lower() + " options in the build palette (the world is not affected)"
		check.button_pressed = name != "HUD layout"
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
	scroll.custom_minimum_size = Vector2(0, 240)  # the palette never gets squeezed out by what sits below it
	outer.add_child(scroll)
	_fat_scrollbar(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	var gutter := MarginContainer.new()  # keeps the cards clear of the wide scrollbar
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 26)
	gutter.add_child(col)
	scroll.add_child(gutter)
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
			if def.kind == "ground":
				b.icon = PlacedObjects.ground_texture(id)
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "grass":
				b.icon = load(WindGrassTileset.DIR + id + ".png") as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "wall":
				b.icon = PlacedObjects.wall_texture(id)
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "pickup":
				b.icon = HealthGourd.icon(str(def.get("gourd", "health")))
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
			for sn in ["normal", "hover", "pressed", "hover_pressed"]:
				(b.get_theme_stylebox(sn) as StyleBoxFlat).content_margin_left = 3
				(b.get_theme_stylebox(sn) as StyleBoxFlat).content_margin_right = 3
			b.add_theme_font_size_override("font_size", 11)
			b.pressed.connect(func(): set_tool("paint" if tool == "paint" and PlacedObjects.def_of(id).kind in ["ground", "grass"] else "place", id))
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

	# HUD pieces: pick one here (or click it in the game view) and drag it where it should go
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 6)
	hud_box.visible = false
	outer.add_child(hud_box)
	_category_sections["HUD layout"] = hud_box
	_section(hud_box, "HUD pieces")
	var hud_grid := GridContainer.new()
	hud_grid.columns = 2
	hud_grid.add_theme_constant_override("h_separation", 4)
	hud_grid.add_theme_constant_override("v_separation", 4)
	hud_box.add_child(hud_grid)
	for id in HealthBar.ELEMENTS:
		var hb := Button.new()
		hb.text = HealthBar.ELEMENT_NAMES[id]
		hb.toggle_mode = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.clip_text = true
		_skin(hb)
		hb.add_theme_font_size_override("font_size", 11)
		hb.pressed.connect(select_hud.bind(id))
		hud_grid.add_child(hb)
		_hud_buttons[id] = hb
	var hud_reset := Button.new()
	hud_reset.text = "RESET HUD LAYOUT"
	hud_reset.focus_mode = Control.FOCUS_NONE
	_skin(hud_reset)
	hud_reset.pressed.connect(func():
		if hud_bar() != null:
			hud_bar().reset_layout()
		_flash("HUD layout reset"))
	hud_box.add_child(hud_reset)
	hud_snap_button = Button.new()
	hud_snap_button.focus_mode = Control.FOCUS_NONE
	_skin(hud_snap_button)
	hud_snap_button.pressed.connect(func():
		if hud_bar() != null:
			hud_bar().cycle_snap()
		_refresh())
	hud_box.add_child(hud_snap_button)
	var hud_inline := Button.new()
	hud_inline.text = "ALIGN SUBSTITUTION WITH R2"
	hud_inline.focus_mode = Control.FOCUS_NONE
	_skin(hud_inline)
	hud_inline.pressed.connect(func():
		if hud_bar() != null:
			hud_bar().align_substitution_with_r2()
			_flash("Substitution lined up with the R2 buttons"))
	hud_box.add_child(hud_inline)
	var hud_right := Button.new()
	hud_right.text = "R2 BUTTONS TO RIGHT EDGE"
	hud_right.focus_mode = Control.FOCUS_NONE
	_skin(hud_right)
	hud_right.pressed.connect(func():
		if hud_bar() != null:
			hud_bar().r2_to_right_edge()
			_flash("R2 buttons moved to the far right"))
	hud_box.add_child(hud_right)

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
	# Desktop/editor only -- deliberately not created at all on Web, so the publish path (and the
	# git operations it runs) cannot exist in the publicly-playable browser build.
	if not OS.has_feature("web"):
		var pub := Button.new()
		pub.text = "PUBLISH"
		pub.tooltip_text = "Commit + push this layout to GitHub (desktop only, uses this machine's own git login)"
		pub.focus_mode = Control.FOCUS_NONE
		pub.custom_minimum_size = Vector2(0, 38)
		_skin(pub)
		pub.pressed.connect(publish_to_github)
		saves.add_child(pub)

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
	# The filters only declutter the BUILD PALETTE; the game world is never hidden by them.
	(_category_sections[category] as Control).visible = shown
	if category == "HUD layout" and not shown and hud_bar() != null:
		hud_bar().select_element("")
	(_filter_buttons[category] as CheckBox).set_pressed_no_signal(shown)
	if not shown:
		if place_id != "" and PlacedObjects.type_of(place_id) == category:
			set_tool("select")
	_refresh()


## A wide, easy-to-grab scrollbar (the default is a few pixels wide).
func _fat_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(22, 0)
	var looks := {"scroll": Color(1, 1, 1, 0.06), "grabber": Color(1, 1, 1, 0.35), "grabber_highlight": Color(ACCENT, 0.85), "grabber_pressed": ACCENT}
	for k: String in looks:
		var s := _sbox(looks[k], Color(0, 0, 0, 0), 0, 8)
		s.set_content_margin_all(0)
		bar.add_theme_stylebox_override(k, s)


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


func cycle_brush() -> void:
	brush = BRUSHES[(BRUSHES.find(brush) + 1) % BRUSHES.size()]
	_refresh()


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


## Back to the original arena: the five starting trees and a fresh scatter of health gourds, everything you built removed.
func _reset_pressed() -> void:
	if not _reset_armed:
		_armed_button("_reset_armed")
		return
	_reset_armed = false
	placed.load_dict({"version": 1, "items": []})
	placed.scatter_defaults()  # the starting arena has its gourds lying around
	placed.ensure_shrine()
	selected = {}
	_refresh()


func _refresh() -> void:
	if status == null:
		return
	for k: String in _tool_buttons:
		(_tool_buttons[k] as Button).set_pressed_no_signal(tool == k)
	for id: String in _palette_buttons:
		(_palette_buttons[id] as Button).set_pressed_no_signal(tool in ["place", "paint"] and place_id == id)
	if brush_button != null:
		brush_button.text = "BRUSH  %d x %d" % [brush, brush]
		brush_button.set_pressed_no_signal(false)
	if hud_snap_button != null:
		var hs: int = hud_bar().hud_snap if hud_bar() != null else 0
		hud_snap_button.text = "HUD GRID  %s" % (str(hs) if hs > 0 else "OFF")
	snap_button.text = "GRASS GRID" if snap > 0 and _grass_tool() else "SNAP  %s" % (str(snap) if snap > 0 else "OFF")
	clear_button.text = "SURE?" if _clear_armed else "CLEAR ALL"
	reset_button.text = "SURE?" if _reset_armed else "RESET"
	var hud := hud_bar()
	for id: String in _hud_buttons:
		(_hud_buttons[id] as Button).set_pressed_no_signal(hud != null and hud.selected_element == id)
	inspector.visible = not selected.is_empty()
	if not selected.is_empty():
		inspector_name.text = str(PlacedObjects.def_of(selected.id).label)
		inspector_pos.text = "X %d   Y %d" % [int(selected.pos.x), int(selected.pos.y)]
	var what := "Painting: %s  (drag to lay tiles, %d x %d brush)" % [str(PlacedObjects.CATALOG[place_id].label), brush, brush] if tool == "paint" else "Placing: %s" % str(PlacedObjects.CATALOG[place_id].label) if tool == "place" else ("Erase mode" if tool == "erase" else "Pan: drag the map" if tool == "pan" else "Select / move")
	count_label.text = "%d objects" % placed.objects.size()
	status.text = _note if Time.get_ticks_msec() < _note_until else what
