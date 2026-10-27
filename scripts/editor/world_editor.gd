class_name WorldEditor
extends CanvasLayer
## World Builder: a small collapsible tools panel on the RIGHT edge for placing trees, walls and other built
## objects (PlacedObjects.CATALOG) anywhere in the arena. The BUILD tab opens it (no hotkey).
##   Pick an item in the palette, click the world to place it (right-click or Select to stop).
##   Select / Move: click an object to pick it, drag to move it, Delete removes it.   Erase: click objects to remove them.
## The layout autosaves (user://world_builder_layout.json). While the panel is hidden nothing is editable.
const PANEL_W := 236.0
static var ACCENT := Color("#FF6B00")  ## active-control colour (the black map editor swaps it for white, see use_palette)
const SNAPS: Array[int] = [30, 15, 0]

var arena: TrainingArena
var placed: PlacedObjects
var open := false
var tool := "select"  ## "select" | "erase" | "place" | "paint" | "pan"
const BRUSHES: Array[int] = [1, 3, 5]
var brush := 1  ## paint tool: the brush is a brush x brush block of floor cells
const SHAPES: Array[String] = ["brush", "rect", "line"]
const BANK_LABELS := {"": "AUTO", "grass": "GRASS", "dirt": "DIRT", "rock": "ROCK"}
const TERRAIN_COLORS := {"water": Color("#3aa0ff"), "grass": Color("#4fd25a"), "ground": Color("#b9824a"), "temple": Color("#b8b8c8"), "": Color("#ff4d4d")}
var auto_terrain := "water"  ## terrain tool: "water" | "grass" | "ground" | "temple" | "" (clear floor)
var bank_family := ""  ## terrain tool: "" follows the neighbouring land, else "grass" | "dirt" | "rock"
var shape := "brush"  ## paint / terrain: "brush" (drag), "rect" (drag a box) or "line"
var erase_autofix := true  ## erasing a floor tile re-picks the edges around the hole
var selection: Array = []  ## box-selected objects (group move / copy / delete)
var clipboard: Array = []  ## copied stamp items {id, x, y} relative to an anchor floor cell
var stamp_path := StampStore.PATH
var problems: Array = []
var _problem_i := -1
var _auto: AutoTile = null
var _shaping := false
var _shape_start := Vector2.INF
var _shape_end := Vector2.INF
var _boxing := false
var _box_start := Vector2.INF
var _box_end := Vector2.INF
var _group_dragging := false
var _group_start_world := Vector2.ZERO
var _group_from: Array = []
var _terrain_buttons: Dictionary = {}
var _shape_buttons: Dictionary = {}
var _layer_buttons: Dictionary = {}
var bank_button: Button = null
var stamps_box: VBoxContainer = null
var tools_toggle: Button = null
var tools_body: Control = null
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
var shell: EditorShell = null  ## the all-black map-editor chrome (map editor page only)
var _ui_root: Control = null
var panel_hidden := false  ## map editor: the tools panel is collapsed to its tab
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
var properties: PropertiesPanel = null  ## map editor: the Properties card (editable X / Y, duplicate, delete)
var browser: AssetBrowser = null  ## map editor: TILES / OBJECTS / ENTITIES tabs, search and chips over the palette
var _clear_armed := false
var _js_state: JavaScriptObject
var _hud_buttons: Dictionary = {}
var hud_snap_button: Button = null
## Builder guides (Settings tab), all OFF by default: a white floor grid and, per object type, a box that
## bounds exactly the art. The selected object always shows its own box so you can see what you picked.
const DIM_TYPES: Array[String] = ["Blightwood lights", "Blightwood rocks", "Ashen fire", "Volcanic trees", "Trees", "Temple walls", "Fences", "Grass", "Tall grass", "Ground / paths", "Temple ground"]
var show_grid := false
var void_sheet: Node2D = null
## Map-editor page extras (MapEditorMode.active()): BUILD | SETTINGS tabs, playtest toggle, undo/redo row.
var map_mode := false
var title_label: Label
var sub_label: Label
var hide_button: Button
var build_page: Control
var settings_page: Control
var tab_build_button: Button
var tab_settings_button: Button
var undo_button: Button
var redo_button: Button
var fill_void_button: Button
var next_void_button: Button
const PANEL_W_MAP := 400.0
## Set false only by tests: save/publish normally refuse while white void is left in the level.
var void_check := true
## Cell the last blocked save jumped to (INF = none); drawn as a red diamond on the white void.
var void_focus := Vector2.INF
var show_dims: Dictionary = {}  ## type name -> bool
var _settings_rows_added := false
var _ui: Dictionary = {}  ## map-editor layout pieces captured while the panel is built (rows, filters, footer)
var _map_world_frozen := false
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


## Plain white sheet under everything while the editor is open. The default stone floor is hidden then, so
## white = nothing laid yet (the raw game world) and anything you can see is real, placed floor.
class VoidSheet extends Node2D:
	var editor: WorldEditor
	func _init(e: WorldEditor) -> void:
		editor = e
		z_index = -2
		name = "WorldEditorVoid"
		visible = false
	func _draw() -> void:
		if editor.arena != null:
			draw_rect(editor.arena.ground_rect().grow(400.0), Color.WHITE)
		if editor.void_focus != Vector2.INF:
			var c := editor.void_focus
			var pts := PackedVector2Array([c + Vector2(0, -18), c + Vector2(36, 0), c + Vector2(0, 18), c + Vector2(-36, 0), c + Vector2(0, -18)])
			draw_polyline(pts, Color("#e02020"), 4.0)


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
	void_sheet = VoidSheet.new(self)
	arena.add_child(void_sheet)
	use_palette(MapEditorMode.active())
	_build_ui()
	_show_void(true)
	set_open(false)
	if MapEditorMode.public_game():
		tab.visible = false  # the public game page has no World Builder
	placed.clear_history()
	if map_mode:
		_enter_map_mode()
		shell = EditorShell.new(self)
		_ui_root.add_child(shell)
		shell.build()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		_js_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__EDITOR_STATE__ = _js_state
		if "editor=1" in query:
			set_open(true)


func _process(_d: float) -> void:
	if map_mode and not _map_world_frozen:
		_freeze_world()
	var hud := hud_bar()
	if hud != null and hud.edit_mode != open:
		hud.set_edit_mode(open)
	if not _settings_rows_added and SettingsPanel.instance() != null:
		_add_settings_rows(SettingsPanel.instance())
		if map_mode:
			_adopt_settings_page(SettingsPanel.instance())
	if undo_button != null:
		undo_button.disabled = not placed.can_undo()
		redo_button.disabled = not placed.can_redo()
	if _js_state != null:
		_js_state.open = open
		_js_state.count = placed.objects.size()
		_js_state.shrine_count = placed.objects.filter(func(obj: Dictionary): return obj.id == "dynamic_shrine").size()
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
			_js_state.save_accessible = save_button.is_visible_in_tree() and save_button.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y
			_js_state.grass_count = (arena.get_node("WindGrassField") as WindGrassField).ground_count()
			var ashen_count := 0
			var ashen_capacity := 0
			var ashen_clock := 0.0
			for obj in placed.objects:
				if PlacedObjects.def_of(obj.id).kind == "ashen_tree":
					var tree := obj.nodes[0] as AshenTree
					ashen_count += 1
					ashen_capacity += tree.flakes.size()
					ashen_clock = tree.local_clock
			var fire_count := 0
			var fire_pops := 0
			for obj in placed.objects:
				if PlacedObjects.def_of(obj.id).kind == "ashen_fire":
					fire_count += 1
					fire_pops += (obj.nodes[0] as AshenFireProp).pop_count
			var blight_count := 0
			var swarm_count := 0
			var fly_count := 0
			var light_clock := 0.0
			for obj in placed.objects:
				var kind := str(PlacedObjects.def_of(obj.id).kind)
				if kind == "blight_light":
					var fixture := obj.nodes[0] as BlightwoodLight
					blight_count += 1
					fly_count += fixture.swarm.flies.size()
					light_clock = fixture.clock
				elif kind == "fireflies":
					swarm_count += 1
					fly_count += (obj.nodes[0] as ForestFireflies).flies.size()
			var shore_count := 0
			var water_count := 0
			var water_clock := 0.0
			for obj in placed.objects:
				if obj.nodes[0] is BlightwoodWater:
					water_count += 1
					if not (obj.nodes[0] as BlightwoodWater).shore_family.is_empty():shore_count += 1
					water_clock = (obj.nodes[0] as BlightwoodWater).clock
			_js_state.shore_count = shore_count
			_js_state.water_count = water_count
			_js_state.water_clock = water_clock
			_js_state.blight_count = blight_count
			_js_state.swarm_count = swarm_count
			_js_state.fly_count = fly_count
			_js_state.light_clock = light_clock
			_js_state.fire_count = fire_count
			_js_state.fire_pops = fire_pops
			_js_state.ashen_count = ashen_count
			_js_state.ashen_capacity = ashen_capacity
			_js_state.ashen_clock = ashen_clock
			_js_state.tall_count = (arena.get_node("WindGrassField") as WindGrassField).tall_count()
	if open and inspector != null and inspector.visible and not selected.is_empty():
		inspector_pos.text = "X %d   Y %d" % [int(selected.pos.x), int(selected.pos.y)]


## Map editor only: collapse or restore the tools panel without closing the editor (editing keeps working).
func set_panel_hidden(hidden: bool) -> void:
	if not map_mode:
		return
	panel_hidden = hidden
	if shell != null:
		shell.set_left_open(not hidden)
		return
	panel.visible = not hidden
	tab.visible = hidden


func set_open(v: bool) -> void:
	if v and MapEditorMode.public_game():
		return  # no World Builder on the public game page
	if map_mode and not v:
		return  # the map editor is for building only: it cannot be closed into a playable level
	SpawnMarker.shown = v
	open = v
	placed.set_bandits_frozen(v or map_mode)
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


## The default stone floor is always hidden (editor AND play): white means "no art laid here yet".
func _show_void(on: bool) -> void:
	if void_sheet != null:
		void_sheet.visible = on
		if on:
			void_sheet.queue_redraw()
	if arena == null:
		return
	var tiles := arena.get_node_or_null("Ground/FloorTiles") as TileMapLayer
	if tiles != null:
		tiles.visible = not on


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
	if t not in ["select", "box"]:
		selection = []
	_auto = null
	_shaping = false
	_boxing = false
	_refresh()


func snapped_pos(p: Vector2) -> Vector2:
	if snap > 0 and _grass_tool():
		return iso_cell_center(p)
	if snap > 0 and (_wall_tool() or _bridge_tool()):
		return PlacedObjects.iso_vertex(p)  # wall kit pieces sit on floor-diamond vertices so runs join
	return p if snap <= 0 else (p / float(snap)).round() * float(snap)


## snapped_pos, then (snap on) a stair / cliff ledge end pulled flush onto a nearby piece's joint.
func placement_pos(id: String, p: Vector2, exclude: Dictionary = {}) -> Vector2:
	var at := snapped_pos(p)
	return placed.snap_joint(id, at, exclude) if snap > 0 else at

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


func _bridge_tool() -> bool:
	var id := place_id if tool in ["place", "paint"] else str(selected.get("id", ""))
	return id != "" and PlacedObjects.def_of(id).kind == "bridge"


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
		if map_mode and event.keycode == KEY_H and not event.ctrl_pressed and not (get_viewport().gui_get_focus_owner() is LineEdit):
			set_panel_hidden(not panel_hidden)
			get_viewport().set_input_as_handled()
			return
		if shell != null and not event.ctrl_pressed and not (get_viewport().gui_get_focus_owner() is LineEdit):
			if event.keycode == KEY_BRACKETLEFT:
				shell.set_left_open(not shell.left_open)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_BRACKETRIGHT:
				shell.set_right_open(not shell.right_open)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_G:
				show_grid = not show_grid
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_M:
				shell.set_minimap_open(not shell.minimap_open)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F1:
				shell.toggle_shortcuts()
				get_viewport().set_input_as_handled()
				return
		if open and event.keycode == KEY_S and event.ctrl_pressed:
			save_now()
			get_viewport().set_input_as_handled()
			return
		if open and event.ctrl_pressed and event.keycode == KEY_Z:
			if event.shift_pressed:
				redo()
			else:
				undo()
			get_viewport().set_input_as_handled()
			return
		if open and event.ctrl_pressed and event.keycode == KEY_Y:
			redo()
			get_viewport().set_input_as_handled()
			return
		if open and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and hud_bar() != null and hud_bar().selected_element != "":
			var step := 10.0 if event.shift_pressed else 1.0
			var dir := Vector2(float(event.keycode == KEY_RIGHT) - float(event.keycode == KEY_LEFT), float(event.keycode == KEY_DOWN) - float(event.keycode == KEY_UP))
			hud_bar().move_element(hud_bar().selected_element, dir * step)
			hud_bar().save_layout()
			get_viewport().set_input_as_handled()
			return
		if open and event.ctrl_pressed and event.keycode == KEY_C:
			copy_selection()
			get_viewport().set_input_as_handled()
			return
		if open and event.ctrl_pressed and event.keycode == KEY_V:
			begin_paste()
			get_viewport().set_input_as_handled()
			return
		if open and (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and (not selected.is_empty() or not selection.is_empty()):
			delete_selected()
			get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event is InputEventMouseMotion and _panning:
		pan_by((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _mid_down:
		_mid_moved += (event as InputEventMouseMotion).relative.length()
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
			elif _shaping:
				end_shape(_mouse_world())
			elif _boxing:
				end_box(_mouse_world())
			else:
				release()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and map_mode:
			if mb.pressed:
				_mid_down = true
				_mid_moved = 0.0
			elif _mid_down:
				_mid_down = false
				if _mid_moved < 4.0:  # a click that never moved is still the eyedropper
					eyedrop(_mouse_world(), Input.is_key_pressed(KEY_ALT))
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			eyedrop(_mouse_world(), Input.is_key_pressed(KEY_ALT))
			get_viewport().set_input_as_handled()
		elif map_mode and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			set_tool("select")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and hud_bar() != null and hud_bar().dragging_element:
		hud_bar().drag_at(get_viewport().get_mouse_position(), not Input.is_key_pressed(KEY_SHIFT))
	elif event is InputEventMouseMotion and _stroke:
		paint_to(_mouse_world())
	elif event is InputEventMouseMotion and _shaping:
		_shape_end = iso_cell_center(_mouse_world())
	elif event is InputEventMouseMotion and _boxing:
		_box_end = _mouse_world()
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


const VIEW_ZOOM_MIN := 0.1
const VIEW_ZOOM_MAX := 1.5  ## the camera's max zoom stays 1.5 in the editor too
var _mid_down := false  ## map editor: middle mouse held (drag pans; a click without moving still eyedrops)
var _mid_moved := 0.0


## World point at the middle of the visible canvas.
func view_center() -> Vector2:
	var cam := _camera()
	return cam.get_screen_center_position() if cam != null else Vector2.ZERO


## Move the view so `world` sits in the middle of the free canvas (the part not under a sidebar).
func center_on(world: Vector2) -> void:
	var cam := _camera()
	if cam == null:
		return
	var free_mid := shell.canvas_rect().get_center() if shell != null else get_viewport().get_visible_rect().get_center()
	var want_shift := (get_viewport().get_visible_rect().get_center() - free_mid) / cam.zoom.x  # canvas centre is off the screen centre
	cam.offset += world + want_shift - cam.get_screen_center_position()
	cam.force_update_scroll()


## Zoom by a factor, keeping the world point under `screen` where it is (wheel zoom). Clamped to the editor's range.
func zoom_by(factor: float, screen: Vector2 = Vector2(-1, -1)) -> float:
	var cam := _camera()
	if cam == null:
		return 0.0
	var z0 := cam.zoom.x
	var z1 := clampf(z0 * factor, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	if is_equal_approx(z0, z1):
		return z1
	var vp := get_viewport().get_visible_rect().size
	var pt := screen if screen.x >= 0.0 else (shell.canvas_rect().get_center() if shell != null else vp * 0.5)
	cam.offset += (pt - vp * 0.5) * (1.0 / z0 - 1.0 / z1)
	cam.zoom = Vector2.ONE * z1
	cam.force_update_scroll()
	return z1


## Zoom to an exact value (1.0 = the 100% the status bar shows).
func set_view_zoom(base_ratio: float) -> void:
	var cam := _camera()
	if cam == null:
		return
	var target := clampf(WorldScale.CAMERA_BASE_ZOOM * base_ratio, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	zoom_by(target / cam.zoom.x)


## Show the whole arena in the free canvas.
func fit_map() -> void:
	var cam := _camera()
	if cam == null or arena == null:
		return
	var area := shell.canvas_rect() if shell != null else get_viewport().get_visible_rect()
	var b := arena.bounds
	var z := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y) * 0.95, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	cam.zoom = Vector2.ONE * z
	cam.force_update_scroll()
	center_on(b.get_center())


## The player's HUD (HealthBar canvas layer), or null when there is no player yet.
func hud_bar() -> HealthBar:
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return p.get_node_or_null("HealthBar") as HealthBar if p != null else null


## Builder, select tool: a click on a HUD piece (bars, avatar, pips, ability slots) picks it up instead of a world object.
func press_hud(screen: Vector2) -> bool:
	var hud := hud_bar()
	if not open or tool != "select" or hud == null or map_mode:
		return false  # the map editor has no player HUD to pick up
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
	return block_cells(iso_cell_center(world))


## The brush x brush block of floor cells around floor cell `c`.
func block_cells(c: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var r := (brush - 1) / 2
	for i in range(-r, r + 1):
		for j in range(-r, r + 1):
			out.append(c + Vector2(36.0, 18.0) * float(i) + Vector2(36.0, -18.0) * float(j))
	return out


## Stamp the brush at `world`; true if any tile changed.
func paint_at(world: Vector2) -> bool:
	var any := _apply_cells(brush_cells(world))
	if any:
		_stroke_changed = true
	return any


## Lay the current brush (the terrain tool's auto-tiling, or the chosen floor piece) on `cells`. No commit.
func _apply_cells(cells: Array) -> bool:
	if tool == "terrain":
		if _auto == null:
			_auto = AutoTile.new(placed, bank_family)
		_auto.bank_family = bank_family
		return _auto.apply(cells, auto_terrain) > 0
	var any := false
	for cell: Vector2 in cells:
		if placed.paint_cell(place_id, cell):
			any = true
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
	_auto = null
	_last_cell = Vector2(INF, INF)
	if _stroke_changed:
		_stroke_changed = false
		placed._changed()  # one nav rebuild + one save for the whole stroke
	_refresh()


func press(world: Vector2) -> void:
	if tool in ["paint", "terrain"] and shape != "brush":
		_shaping = true
		_shape_start = iso_cell_center(world)
		_shape_end = _shape_start
		return
	match tool:
		"paint", "terrain":
			_stroke = true
			_stroke_changed = false
			_last_cell = Vector2(INF, INF)
			paint_to(world)
		"place":
			var pos := placement_pos(place_id, world)
			if placed.can_place(place_id, pos):
				selected = {}
				placed.add(place_id, pos)
				_refresh()
		"stamp":
			paste_at(world)
		"box":
			_boxing = true
			_box_start = world
			_box_end = world
		"erase":
			var o := placed.hit_test(world)
			if not o.is_empty():
				if erase_autofix and PlacedObjects.is_floor_tile(o.id):
					AutoTile.new(placed).erase(o)
					placed._changed()
				else:
					placed.remove(o)
				_refresh()
		_:
			var hit := placed.hit_test(world)
			if Input.is_key_pressed(KEY_SHIFT) and tool == "select":
				_boxing = true
				_box_start = world
				_box_end = world
				return
			if not selection.is_empty() and selection.has(hit):
				begin_group_drag(world)
				return
			selection = []
			selected = hit
			dragging = not selected.is_empty()
			if dragging:
				_drag_origin = selected.pos
				_drag_offset = (selected.pos as Vector2) - world
			_refresh()


func drag_to(world: Vector2) -> void:
	if _group_dragging:
		group_drag_to(world)
		return
	if dragging and not selected.is_empty():
		placed.move(selected, placement_pos(selected.id, world + _drag_offset, selected), false)


func release() -> void:
	if _group_dragging:
		end_group_drag()
		return
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


# ------------------------------------------------------------------ builder pro tools
## Floor cells covered by a rect / line drag from floor cell `a` to floor cell `b` (in the floor grid's own axes).
func shape_cells(a: Vector2, b: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var seen := {}
	var d := b - a
	var di := roundi((d.x / 36.0 + d.y / 18.0) * 0.5)
	var dj := roundi((d.x / 36.0 - d.y / 18.0) * 0.5)
	var step_i := Vector2(36, 18)
	var step_j := Vector2(36, -18)
	if shape == "rect":
		for i in range(mini(0, di), maxi(0, di) + 1):
			for j in range(mini(0, dj), maxi(0, dj) + 1):
				out.append(a + step_i * float(i) + step_j * float(j))
		return out
	var n := maxi(absi(di), absi(dj))
	for k in range(n + 1):
		var t := float(k) / float(maxi(n, 1))
		var c := a + step_i * float(roundi(float(di) * t)) + step_j * float(roundi(float(dj) * t))
		for cell in block_cells(c):
			if not seen.has(cell):
				seen[cell] = true
				out.append(cell)
	return out


## Finish a rect / line drag: lay the whole shape as one undo step.
func end_shape(world: Vector2) -> int:
	if not _shaping:
		return 0
	_shaping = false
	_shape_end = iso_cell_center(world)
	return apply_shape(_shape_start, _shape_end)


func apply_shape(a: Vector2, b: Vector2) -> int:
	var cells := shape_cells(a, b)
	_auto = null
	var any := _apply_cells(cells)
	_auto = null
	if any:
		placed._changed()
		_flash("Filled %d cells (Ctrl+Z undoes it)" % cells.size())
	_refresh()
	return cells.size() if any else 0


## Box select: every unlocked, visible object whose centre is inside the dragged box.
func end_box(world: Vector2) -> int:
	if not _boxing:
		return 0
	_boxing = false
	_box_end = world
	return select_in_rect(Rect2(_box_start, Vector2.ZERO).expand(_box_end))


func select_in_rect(area: Rect2) -> int:
	selection = placed.objects_in_rect(area)
	selected = {}
	dragging = false
	if selection.size() == 1:
		selected = selection[0]
		selection = []
	_flash("%d selected: drag to move, Ctrl+C to copy, Del to delete" % selection.size() if selection.size() > 1 else "Nothing in the box" if selected.is_empty() else "1 selected")
	_refresh()
	return selection.size() + (1 if not selected.is_empty() else 0)


func selected_objects() -> Array:
	if not selection.is_empty():
		return selection.duplicate()
	return [selected] if not selected.is_empty() else []


func begin_group_drag(world: Vector2) -> void:
	_group_dragging = true
	_group_start_world = world
	_group_from = []
	for o: Dictionary in selection:
		_group_from.append(o.pos)


func group_drag_to(world: Vector2) -> void:
	var delta := world - _group_start_world
	var has_floor := false
	for o: Dictionary in selection:
		has_floor = has_floor or PlacedObjects.is_floor_tile(o.id)
	if has_floor:
		var c0 := iso_cell_center(_group_start_world)
		delta = iso_cell_center(_group_start_world + delta) - c0  # floor pieces stay on the floor grid
	elif snap > 0:
		delta = (delta / float(snap)).round() * float(snap)
	for i in selection.size():
		placed.move(selection[i], (_group_from[i] as Vector2) + delta, false)


func end_group_drag() -> void:
	_group_dragging = false
	var ok := true
	for o: Dictionary in selection:
		if not PlacedObjects.is_floor_tile(o.id) and not placed.can_place(o.id, o.pos):
			ok = false
	if not ok:
		for i in selection.size():
			placed.move(selection[i], _group_from[i], false)
		_flash("Cannot drop the group there")
	else:
		for o: Dictionary in selection:  # a moved floor tile replaces whatever floor it lands on
			if PlacedObjects.is_floor_tile(o.id):
				for other in placed.floor_tiles_in_cell(PlacedObjects.lattice_center(o.pos)):
					if other != o and not selection.has(other):
						placed.remove(other, false)
	placed._changed()
	_refresh()


func copy_selection() -> int:
	var objs := selected_objects()
	clipboard = StampStore.capture(objs)
	_flash("Copied %d objects: Ctrl+V or PASTE, then click to drop" % clipboard.size() if not clipboard.is_empty() else "Select something first (BOX SELECT, or Shift + drag)")
	_refresh()
	return clipboard.size()


func begin_paste() -> void:
	if clipboard.is_empty():
		_flash("Nothing copied yet")
		return
	set_tool("stamp")
	_flash("Click to drop the copy, right-click to stop")


func paste_at(world: Vector2) -> int:
	if clipboard.is_empty():
		return 0
	var made := placed.paste(clipboard, iso_cell_center(world))
	_flash("Pasted %d objects (Ctrl+Z undoes it)" % made.size())
	_refresh()
	return made.size()


func save_stamp(stamp_name := "") -> bool:
	var items := StampStore.capture(selected_objects()) if not selected_objects().is_empty() else clipboard
	if items.is_empty():
		_flash("Select or copy something, then SAVE STAMP")
		return false
	var nm := stamp_name if stamp_name != "" else "Stamp %d" % (StampStore.load_all(stamp_path).size() + 1)
	var ok := StampStore.add(nm, items, stamp_path)
	_rebuild_stamps()
	_flash("Saved %s" % nm if ok else "Could not save the stamp")
	return ok


func use_stamp(index: int) -> void:
	var all := StampStore.load_all(stamp_path)
	if index < 0 or index >= all.size():
		return
	clipboard = (all[index] as Dictionary).items
	begin_paste()


func delete_stamp(index: int) -> void:
	StampStore.remove(index, stamp_path)
	_rebuild_stamps()


func _rebuild_stamps() -> void:
	if stamps_box == null:
		return
	for c in stamps_box.get_children():
		stamps_box.remove_child(c)
		c.queue_free()
	var all := StampStore.load_all(stamp_path)
	for i in all.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		stamps_box.add_child(row)
		var use := _mini(row, "%s  (%d)" % [str(all[i].name), (all[i].items as Array).size()], use_stamp.bind(i), false)
		use.tooltip_text = "Load this stamp, then click the map to drop it"
		var x := _mini(row, "X", delete_stamp.bind(i), false)
		x.size_flags_horizontal = Control.SIZE_SHRINK_END
		x.tooltip_text = "Delete this saved stamp"


## Middle-click: make the piece under the cursor the current brush (Alt: the floor tile under it).
func eyedrop(world: Vector2, floor_only := false) -> bool:
	var o: Dictionary = {}
	if floor_only:
		var tiles := placed.floor_tiles_in_cell(iso_cell_center(world))
		o = tiles.back() if not tiles.is_empty() else {}
	else:
		o = placed.hit_test(world)
	if o.is_empty():
		_flash("Nothing here to pick up")
		return false
	var id: String = o.id
	if PlacedObjects.is_floor_tile(id):
		var t := AutoTile.terrain_of(id)
		if tool == "terrain" and t in AutoTile.TERRAINS:
			auto_terrain = t
			_refresh()
		else:
			set_tool("paint", id)
	else:
		set_tool("place", id)
	_flash("Picked %s" % str(PlacedObjects.def_of(id).get("label", id)))
	return true


func set_terrain(t: String) -> void:
	auto_terrain = t
	set_tool("terrain")


func cycle_bank() -> void:
	var fams := AutoTile.BANK_FAMILIES
	bank_family = fams[(fams.find(bank_family) + 1) % fams.size()]
	_refresh()


func set_shape(sh: String) -> void:
	shape = sh
	_shaping = false
	if tool not in ["paint", "terrain"]:
		set_terrain(auto_terrain)
	_refresh()


func set_layer_hidden(category: String, hidden: bool) -> void:
	placed.set_type_visible(category, not hidden)
	_refresh()


func set_layer_locked(category: String, locked: bool) -> void:
	placed.set_type_locked(category, locked)
	if locked and not selected.is_empty() and PlacedObjects.type_of(selected.id) == category:
		selected = {}
	selection = selection.filter(func(o): return PlacedObjects.type_of(o.id) != category)
	_refresh()


func toggle_erase_autofix() -> void:
	erase_autofix = not erase_autofix
	_refresh()


func clear_problem_flags() -> void:
	problems = []
	_refresh()


func scan_problems() -> int:
	problems = ProblemScan.scan(placed)
	_problem_i = -1
	_flash("%d problems found: NEXT PROBLEM flies to each" % problems.size() if not problems.is_empty() else "No problems found")
	return problems.size()


func next_problem() -> void:
	if problems.is_empty() and scan_problems() == 0:
		return
	_problem_i = (_problem_i + 1) % problems.size()
	var pr: Dictionary = problems[_problem_i]
	var cam := _camera()
	if not open:
		set_open(true)
	if cam != null:
		cam.offset += (pr.pos as Vector2) - cam.get_screen_center_position()
		cam.force_update_scroll()
	_flash("%d/%d  %s" % [_problem_i + 1, problems.size(), str(pr.msg)])


## Explicit save: writes the layout to the game's save slot (it also autosaves on every edit) and says so.
func save_now() -> bool:
	if _void_blocks_save():
		return false
	var ok := placed.save()
	_flash("SAVED  %d objects" % placed.objects.size() if ok else "SAVE FAILED")
	return ok


## Move the view to the void cell nearest the current view centre (skipping the one it is already on) and mark it.
func _focus_void(cells: Array) -> void:
	var cam := _camera()
	var from := cam.get_screen_center_position() if cam != null else Vector2.ZERO
	var best := Vector2.INF
	for c: Vector2 in cells:
		if cells.size() > 1 and c == void_focus:
			continue
		if best == Vector2.INF or c.distance_squared_to(from) < best.distance_squared_to(from):
			best = c
	void_focus = best
	if not open:
		set_open(true)
	if cam != null:
		cam.offset += best - cam.get_screen_center_position()
		cam.force_update_scroll()
	if void_sheet != null:
		void_sheet.queue_redraw()


func jump_to_next_void() -> void:
	var cells := placed.void_cells(arena.bounds)
	if cells.is_empty():
		void_focus = Vector2.INF
		_flash("No white void left: every cell has art")
		return
	_focus_void(cells)
	_flash("%d white void cells left. View is on the nearest one." % cells.size())


## Lay the selected ground (or the stone floor) on every empty cell. One undo step.
func fill_void() -> void:
	var id := place_id if place_id != "" and PlacedObjects.is_floor_tile(place_id) else "temple_floor_center"
	var made := placed.fill_void(id, arena.bounds)
	void_focus = Vector2.INF
	_flash("Filled %d void cells with %s (Ctrl+Z undoes it)" % [made, str(PlacedObjects.def_of(id).label)] if made > 0 else "No white void to fill")
	_refresh()


func undo() -> void:
	selected = {}
	selection = []
	_flash("Undone" if placed.undo() else "Nothing to undo")
	_refresh()


func redo() -> void:
	selected = {}
	selection = []
	_flash("Redone" if placed.redo() else "Nothing to redo")
	_refresh()


# ------------------------------------------------------------------ map-editor page
func _build_map_tabs(outer: VBoxContainer, foot: Control) -> void:
	map_mode = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	outer.add_child(row)
	outer.move_child(row, 2)
	var group := ButtonGroup.new()
	tab_build_button = _toggle(row, "BUILD", func(): _show_page(true))
	tab_settings_button = _toggle(row, "SETTINGS", func(): _show_page(false))
	tab_build_button.button_group = group
	tab_settings_button.button_group = group
	tab_build_button.button_pressed = true
	build_page = VBoxContainer.new()
	build_page.name = "BuildPage"
	build_page.add_theme_constant_override("separation", 8)
	build_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The bottom of the panel is PINNED (outside the scrolling build page) so SAVE and the rest are always on screen.
	var dock := VBoxContainer.new()
	dock.name = "PinnedDock"
	dock.add_theme_constant_override("separation", 6)
	var edit_row := _ui["edit_row"] as HBoxContainer
	var void_row := _ui["void_row"] as HBoxContainer
	for b in void_row.get_children():  # UNDO REDO FILL NEXT on one row
		void_row.remove_child(b)
		edit_row.add_child(b)
		(b as Button).add_theme_font_size_override("font_size", 12)
	void_row.queue_free()
	var opts := _ui["opts"] as HBoxContainer
	var io := _ui["io"] as HBoxContainer
	for b in io.get_children():  # SNAP COPY RESET CLEAR on one row
		io.remove_child(b)
		opts.add_child(b)
	io.queue_free()
	for n in [_ui["saves"], opts]:
		outer.remove_child(n)
		dock.add_child(n)
	outer.remove_child(foot)
	dock.add_child(foot)
	(_ui["hints"] as Control).visible = false
	outer.add_child(dock)
	# The 12 palette filters collapse behind one button so they stop eating the panel.
	var filters := _ui["filters"] as Control
	filters.visible = false
	var ftoggle := _toggle(outer, "FILTERS  v", func(): pass)
	ftoggle.toggle_mode = true
	ftoggle.button_pressed = false
	ftoggle.toggled.connect(func(on: bool):
		filters.visible = on
		ftoggle.text = "FILTERS  ^" if on else "FILTERS  v")
	outer.move_child(ftoggle, filters.get_index())
	var movers: Array[Node] = []
	for i in range(3, outer.get_child_count()):
		if outer.get_child(i) != dock:
			movers.append(outer.get_child(i))
	for n in movers:
		outer.remove_child(n)
		build_page.add_child(n)
	outer.add_child(build_page)
	outer.move_child(build_page, 3)
	palette_scroll.custom_minimum_size = Vector2(0, 90)
	if brush_button != null:
		brush_button.visible = false  # the browser's brush row replaces the cycling BRUSH button
	ftoggle.visible = false  # the asset browser's tabs, search and chips replace the 20 filter boxes
	browser = AssetBrowser.new()
	browser.setup(self)
	build_page.add_child(browser)
	build_page.move_child(browser, ftoggle.get_index())
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsPage"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	var box := VBoxContainer.new()
	box.name = "SettingsBox"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	outer.add_child(scroll)
	outer.move_child(scroll, 4)
	settings_page = box


func _show_page(build: bool) -> void:
	if build_page != null:
		build_page.visible = build
	if settings_page != null:
		settings_page.get_parent().visible = not build


func _enter_map_mode() -> void:
	panel.offset_left = -PANEL_W_MAP
	panel.offset_top = 8
	panel.offset_bottom = -8
	panel.clip_contents = true
	title_label.text = "SHINOBI RUSH MAP EDITOR"
	sub_label.text = "BUILD  -  SETTINGS"
	# The editor itself cannot be closed (build only), but the PANEL can slide away to see the whole map:
	# HIDE collapses it to a small tab on the right edge, and the tab (or the H key) brings it back.
	hide_button.pressed.disconnect(hide_button.pressed.get_connections()[0].callable)
	hide_button.pressed.connect(func(): set_panel_hidden(true))
	hide_button.tooltip_text = "Hide this panel (press H or click the tab to bring it back)"
	tab.text = "<  PANEL"
	tab.pressed.disconnect(tab.pressed.get_connections()[0].callable)
	tab.pressed.connect(func(): set_panel_hidden(false))
	tab.visible = false
	if _filter_buttons.has("HUD layout"):
		(_filter_buttons["HUD layout"] as Control).visible = false  # the player HUD is not part of the map
	set_open(true)
	_freeze_world()
	if OS.has_feature("web"):
		var game := Button.new()
		game.text = "OPEN GAME"
		game.focus_mode = Control.FOCUS_NONE
		_skin(game)
		game.pressed.connect(func(): MapEditorMode.open_page("index.html"))
		(hide_button.get_parent() as Control).add_child(game)
		(hide_button.get_parent() as Control).move_child(game, 1)


## The map editor is for building only: the player, the enemies and the player HUD are put away and frozen.
## Safe to call every frame until the world has spawned them (it stops once the player exists).
func _freeze_world() -> void:
	if not map_mode or _map_world_frozen or arena == null or not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node
	if player == null:
		return
	_map_world_frozen = true
	placed.set_bandits_frozen(true)
	var hud := hud_bar()
	if hud != null:
		hud.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(player as CanvasItem).visible = false
	for c in arena.get_children():
		if c is Bandit and not c.has_meta("placed"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
			(c as CanvasItem).visible = false
	_set_camera_free(true)


## The Settings dock (vision switches, camera zoom, Lab / Player / Controls / Diagnostics) lives inside the editor's
## SETTINGS tab on the map-editor page; the little popup on the bottom edge is hidden.
func _adopt_settings_page(sp: SettingsPanel) -> void:
	if settings_page == null or sp.rows == null:
		return
	sp.rows.get_parent().remove_child(sp.rows)
	settings_page.add_child(sp.rows)
	sp.rows.visible = true
	for row: Variant in sp.tab_rows.values():  # Lab / Player / Controls / Diagnostics are game panels, not map tools
		if is_instance_valid(row):
			(row as Control).visible = false
	for b: Variant in [sp.bandit_button, sp.sense_button]:  # enemy debug switches: not needed to build a map
		if b != null and is_instance_valid(b):
			(b as Control).visible = false
	if sp.tab != null:
		sp.tab.visible = false
	if sp.panel != null:
		sp.panel.visible = false


## Save checker: any floor cell with no art on it shows as white void. Returns true (and refuses the save) when
## there is any; the view jumps to the void cell nearest the current view and marks it with a red diamond.
func _void_blocks_save() -> bool:
	if not void_check or arena == null:
		return false
	var cells := placed.void_cells(arena.bounds)
	if cells.is_empty():
		void_focus = Vector2.INF
		return false
	_focus_void(cells)
	_flash("SAVE BLOCKED: %d white void cells have no art. View jumped to the nearest one." % cells.size())
	return true


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
	if _void_blocks_save():
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


## Properties X / Y: move the selected object to an exact spot. Returns false (and says why) when it is not allowed.
func move_selected_to(target: Vector2) -> bool:
	if selected.is_empty():
		return false
	if placed.type_locked(selected.id):
		_flash("That layer is locked")
		return false
	var pos := target
	var is_floor := PlacedObjects.is_floor_tile(selected.id)
	if is_floor:
		pos = iso_cell_center(target)
	if pos.is_equal_approx(selected.pos):
		return true
	if not placed.can_place(selected.id, pos):
		_flash("Cannot move it there")
		_refresh()
		return false
	if is_floor:  # a floor tile replaces whatever floor it lands on
		for other in placed.floor_tiles_in_cell(PlacedObjects.lattice_center(pos)):
			if other != selected:
				placed.remove(other, false)
	placed.move(selected, pos, true)
	_refresh()
	return true


## Properties DUPLICATE: a copy beside the selection (the first free spot), selected so it can be dragged away.
func duplicate_selected() -> bool:
	if selected.is_empty() or placed.type_locked(selected.id):
		return false
	var id := str(selected.id)
	if str(PlacedObjects.def_of(id).kind) == "spawn":
		_flash("There is only one player spawn")
		return false
	var fp := PlacedObjects.footprint_of(id)
	var is_floor := PlacedObjects.is_floor_tile(id)
	var offsets: Array[Vector2] = [Vector2(fp.x + 8.0, 0), Vector2(-fp.x - 8.0, 0), Vector2(0, fp.y + 8.0), Vector2(0, -fp.y - 8.0)]
	if is_floor:
		offsets = [Vector2(36, 18), Vector2(36, -18), Vector2(72, 0)]
	for off in offsets:
		var pos: Vector2 = selected.pos + off
		if not placed.can_place(id, pos):
			continue
		if is_floor:
			for other in placed.floor_tiles_in_cell(PlacedObjects.lattice_center(pos)):
				placed.remove(other, false)
		var made := placed.add(id, pos)
		if made.is_empty():
			continue
		selected = made
		selection = []
		dragging = false
		_flash("Duplicated %s (Ctrl+Z undoes it)" % str(PlacedObjects.def_of(id).label))
		_refresh()
		return true
	_flash("No free spot next to it")
	return false


func delete_selected() -> void:
	if not selection.is_empty():
		var n := 0
		for o: Dictionary in selection.duplicate():
			if placed.objects.has(o) and not placed.type_locked(o.id):
				placed.remove(o, false)
				n += 1
		selection = []
		if n > 0:
			placed._changed()
		_flash("Deleted %d objects (Ctrl+Z undoes it)" % n)
		_refresh()
		return
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
	if OS.has_feature("web") and not MapEditorMode.active():
		var link := Button.new()
		link.name = "MapEditorLink"
		link.text = "Shinobi Rush Map Editor  >"
		link.tooltip_text = "Open the full map editor page in a new tab"
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_font_size_override("font_size", 12)
		link.pressed.connect(func() -> void: MapEditorMode.open_page("editor.html"))
		sp.rows.add_child(link)


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
	for o: Dictionary in selection:
		if placed.objects.has(o):
			c.draw_rect(PlacedObjects.art_rect(o.id, o.pos), Color(1, 0.84, 0.2, 0.95), false, 3.0)
	if _boxing:
		var br := Rect2(_box_start, Vector2.ZERO).expand(_box_end)
		c.draw_rect(br, Color(ACCENT, 0.12))
		c.draw_rect(br, Color(ACCENT, 0.95), false, 2.0)
	var over_world := get_viewport().gui_get_hovered_control() == null
	if tool in ["paint", "terrain"] and shape != "brush" and over_world:
		var a := _shape_start if _shaping else iso_cell_center(_mouse_world())
		var b := _shape_end if _shaping else a
		var tint: Color = TERRAIN_COLORS.get(auto_terrain, ACCENT) if tool == "terrain" else ACCENT
		for cell in shape_cells(a, b):
			c.draw_colored_polygon(_diamond(cell), Color(tint, 0.28))
			c.draw_polyline(_diamond(cell), Color(tint, 0.9), 1.5)
	elif tool == "terrain" and over_world:
		var tint2: Color = TERRAIN_COLORS.get(auto_terrain, ACCENT)
		for cell in brush_cells(_mouse_world()):
			c.draw_colored_polygon(_diamond(cell), Color(tint2, 0.3))
			c.draw_polyline(_diamond(cell), Color(tint2, 0.95), 2.0)
	if tool == "stamp" and not clipboard.is_empty() and over_world:
		var origin := iso_cell_center(_mouse_world())
		for it in clipboard:
			var at: Array = PlacedObjects.art_texture(it.id, origin + Vector2(float(it.x), float(it.y)))
			if at[0] != null:
				c.draw_texture_rect(at[0], Rect2(at[1], (at[0] as Texture2D).get_size() * PlacedObjects.art_scale(it.id)), false, Color(1, 1, 1, 0.6))
	for pr: Dictionary in problems:
		var col := Color(1, 0.25, 0.25, 0.95) if pr.kind in ["overlap", "stacked"] else Color(1, 0.8, 0.1, 0.95)
		c.draw_arc(pr.pos, 26.0, 0.0, TAU, 28, col, 3.0)
		c.draw_circle(pr.pos, 4.0, col)
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
		var pos := placement_pos(place_id, _mouse_world())
		var ok := placed.can_place(place_id, pos)
		# The ghost is the art itself: normal tint when the spot is legal, red when it is not. No separate
		# footprint square (it never covered the art and did not guide placement).
		var at := PlacedObjects.art_texture(place_id, pos)
		var gtex: Texture2D = at[0]
		var gcol := Color(1, 1, 1, 0.6) if ok else Color(1, 0.4, 0.4, 0.6)
		if gtex != null:
			c.draw_texture_rect(gtex, Rect2(at[1], gtex.get_size() * PlacedObjects.art_scale(place_id)), false, gcol)
		else:
			c.draw_rect(PlacedObjects.hit_rect(place_id, pos), Color(gcol, 0.3))
		if dims_on(PlacedObjects.type_of(place_id)) or not ok:
			c.draw_rect(PlacedObjects.art_rect(place_id, pos), Color(ACCENT, 0.9) if ok else Color(1, 0.3, 0.3, 0.95), false, 2.0)


# ------------------------------------------------------------------ UI
static var BG := Color("#0c0c10")
static var CARD := Color("#16161c")
static var CARD_HOVER := Color("#1f1f27")
static var EDGE := Color("#2b2b35")
static var DANGER := Color("#ff4d4d")
static var MUTED := Color(1, 1, 1, 0.55)


## The in-game World Builder keeps its orange look; the Map Editor page is all black / white / grey.
static func use_palette(black: bool) -> void:
	if black:
		ACCENT = Color("#F5F5F5")
		BG = Color("#101010")
		CARD = Color("#191919")
		CARD_HOVER = Color("#242424")
		EDGE = Color("#303030")
		DANGER = Color("#c25555")
		MUTED = Color("#A0A0A0")
	else:
		ACCENT = Color("#FF6B00")
		BG = Color("#0c0c10")
		CARD = Color("#16161c")
		CARD_HOVER = Color("#1f1f27")
		EDGE = Color("#2b2b35")
		DANGER = Color("#ff4d4d")
		MUTED = Color(1, 1, 1, 0.55)

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
	var def: Dictionary = PlacedObjects.def_of(id)
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
	_ui_root = root
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
	_ui["head"] = head
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	var title := Label.new()
	title_label = title
	title.text = "WORLD BUILDER"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color.WHITE)
	titles.add_child(title)
	var sub := Label.new()
	sub_label = sub
	sub.text = "SHINOBI RUSH"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", ACCENT)
	titles.add_child(sub)
	var hide := Button.new()
	hide_button = hide
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
	_ui["bar"] = bar

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
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 6)
	outer.add_child(edit_row)
	undo_button = Button.new()
	undo_button.text = "UNDO"
	undo_button.tooltip_text = "Undo the last action (Ctrl+Z)"
	undo_button.focus_mode = Control.FOCUS_NONE
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(undo_button)
	undo_button.pressed.connect(undo)
	edit_row.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "REDO"
	redo_button.tooltip_text = "Redo (Ctrl+Y or Ctrl+Shift+Z)"
	redo_button.focus_mode = Control.FOCUS_NONE
	redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(redo_button)
	redo_button.pressed.connect(redo)
	edit_row.add_child(redo_button)
	var void_row := HBoxContainer.new()
	_ui["edit_row"] = edit_row
	_ui["void_row"] = void_row
	void_row.add_theme_constant_override("separation", 6)
	outer.add_child(void_row)
	fill_void_button = Button.new()
	fill_void_button.text = "FILL VOID"
	fill_void_button.tooltip_text = "Lay the selected ground tile on every white (empty) cell. One undo step."
	fill_void_button.focus_mode = Control.FOCUS_NONE
	fill_void_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(fill_void_button)
	fill_void_button.pressed.connect(fill_void)
	void_row.add_child(fill_void_button)
	next_void_button = Button.new()
	next_void_button.text = "NEXT VOID"
	next_void_button.tooltip_text = "Jump the view to the nearest white (empty) cell"
	next_void_button.focus_mode = Control.FOCUS_NONE
	next_void_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(next_void_button)
	next_void_button.pressed.connect(jump_to_next_void)
	void_row.add_child(next_void_button)

	_build_pro_tools(outer)

	# Palette filters: hide/show the option cards by type; the world itself is untouched.
	var filter_box := VBoxContainer.new()
	filter_box.add_theme_constant_override("separation", 4)
	_ui["filters"] = filter_box
	outer.add_child(filter_box)
	var all_row := HBoxContainer.new()
	all_row.add_theme_constant_override("separation", 6)
	filter_box.add_child(all_row)
	var select_all := _toggle(all_row, "SELECT ALL", func(): set_all_filters(true))
	select_all.toggle_mode = false
	select_all.tooltip_text = "Show every option group in the build palette"
	var deselect_all := _toggle(all_row, "DESELECT ALL", func(): set_all_filters(false))
	deselect_all.toggle_mode = false
	deselect_all.tooltip_text = "Hide every option group, then tick just the ones you want"
	var filters := GridContainer.new()
	filters.columns = 3
	filter_box.add_child(filters)
	var filter_cats: Array = PlacedObjects.CATEGORIES.duplicate()
	filter_cats.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).nocasecmp_to(str(b[0])) < 0)
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
			var def: Dictionary = PlacedObjects.def_of(id)
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
			if def.kind == "spawn":
				b.icon = SpawnMarker.icon()
				b.add_theme_constant_override("icon_max_width", 48)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "ground":
				b.icon = PlacedObjects.ground_texture(id)
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "water_fx":
				b.icon = load(BlightwoodWater.DIR + "waterfall-icon.png") as Texture2D
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
			elif def.kind == "dynamic_shrine":
				b.icon = load(DynamicShrine.DIR + "assembled.png") as Texture2D
				b.add_theme_constant_override("icon_max_width",64)
				b.custom_minimum_size = Vector2(0,96)
			elif def.kind == "blight_light":
				b.icon = load(str(PlacedObjects.blight_info(int(def.light)).path).replace(".png", "-assembled.png")) as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "fireflies":
				b.icon = load("res://assets/vfx/blightwood_lights/firefly-icon.png") as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 76)
			elif def.kind == "ashen_fire":
				b.icon = load(str(PlacedObjects.fire_info(int(def.fire)).path)) as Texture2D
				b.add_theme_constant_override("icon_max_width",64)
				b.custom_minimum_size = Vector2(0,96)
			elif def.kind == "ashen_tree":
				b.icon = load(str(PlacedObjects.ashen_info(int(def.tree)).texture)) as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "bandit":
				b.icon = PlacedObjects.art_texture(id, Vector2.ZERO)[0] as Texture2D
				b.add_theme_constant_override("icon_max_width", 64)
				b.custom_minimum_size = Vector2(0, 96)
			elif def.kind == "bridge":
				b.icon = PlacedObjects.art_texture(id, Vector2.ZERO)[0] as Texture2D
				b.add_theme_constant_override("icon_max_width", 96)
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
	_ui["saves"] = saves
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
	_ui["opts"] = opts
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
	_ui["io"] = io
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
	_ui["hints"] = hints
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
	if MapEditorMode.active():
		_build_map_tabs(outer, foot)


## SELECT ALL / DESELECT ALL for the palette filters. The HUD layout group is not part of "all" on the map editor.
func set_all_filters(shown: bool) -> void:
	for category: String in _filter_buttons:
		if category == "HUD layout" and map_mode:
			continue
		set_type_filter(category, shown)


func set_type_filter(category: String, shown: bool) -> void:
	# The filters only declutter the BUILD PALETTE; the game world is never hidden by them.
	(_category_sections[category] as Control).visible = shown
	if category == "HUD layout" and not shown and hud_bar() != null:
		hud_bar().select_element("")
	(_filter_buttons[category] as CheckBox).set_pressed_no_signal(shown)
	if browser != null:
		browser.apply()
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


## A compact button for the pro-tools block.
func _mini(parent: Node, text: String, cb: Callable, toggle := true) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(64, 30)
	b.clip_text = true
	_skin(b, "tool")
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Every layer name the catalog can produce, for the HIDE / LOCK rows.
static func layer_names() -> Array[String]:
	var seen := {}
	for id: String in PlacedObjects.CATALOG:
		seen[PlacedObjects.type_of(id)] = true
	var out: Array[String] = []
	for k: String in seen:
		out.append(k)
	out.sort()
	return out


func _flow(parent: Node) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(f)
	return f


## AUTO-TILE + the rest of the pro tools: one collapsible, scrolling block so it never squeezes SAVE off the panel.
func _build_pro_tools(outer: VBoxContainer) -> void:
	tools_toggle = _toggle(outer, "AUTO-TILE & TOOLS  ^", func(): set_pro_tools_open(not tools_body.visible))
	tools_toggle.toggle_mode = false
	var scroll := ScrollContainer.new()
	scroll.name = "ProTools"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 104)
	outer.add_child(scroll)
	_fat_scrollbar(scroll)
	tools_body = scroll
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 24)
	scroll.add_child(gutter)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	gutter.add_child(col)

	_section(col, "Auto-tile terrain  (edges and banks pick themselves)")
	var trow := _flow(col)
	for t: String in ["water", "grass", "ground", "temple", ""]:
		var label := "CLEAR" if t == "" else t.to_upper()
		_terrain_buttons[t] = _mini(trow, label, set_terrain.bind(t))
		(_terrain_buttons[t] as Button).tooltip_text = "Paint %s: the right edge, corner or bank piece is chosen for every cell you touch" % label.to_lower()
	bank_button = _mini(col, "BANK LOOK", cycle_bank, false)
	bank_button.tooltip_text = "Which bank art water gets next to land: follow the land, or force grass / dirt / rock"
	var srow := _flow(col)
	for sh: String in SHAPES:
		_shape_buttons[sh] = _mini(srow, "DRAG" if sh == "brush" else sh.to_upper(), set_shape.bind(sh))
	(_shape_buttons["brush"] as Button).tooltip_text = "Paint along the mouse path with the brush size"
	(_shape_buttons["rect"] as Button).tooltip_text = "Drag a box (along the floor grid) and fill it in one undo step"
	(_shape_buttons["line"] as Button).tooltip_text = "Drag a straight line of floor cells, brush wide"
	var erow := _flow(col)
	var fix := _mini(erow, "ERASE FIXES EDGES", toggle_erase_autofix)
	fix.tooltip_text = "When you erase a floor tile, the pieces around the hole re-pick their edges"
	_terrain_buttons["_fix"] = fix

	_section(col, "Select, copy, stamps")
	var brow := _flow(col)
	_tool_buttons["box"] = _mini(brow, "BOX SELECT", func(): set_tool("box"))
	(_tool_buttons["box"] as Button).tooltip_text = "Drag a box to select a group (Shift + drag works with SELECT too), then drag to move, Del to delete"
	_mini(brow, "COPY", copy_selection, false).tooltip_text = "Copy the selection (Ctrl+C)"
	_mini(brow, "PASTE", begin_paste, false).tooltip_text = "Drop the copy where you click (Ctrl+V)"
	_mini(brow, "SAVE STAMP", save_stamp, false).tooltip_text = "Keep the selection as a named stamp you can drop again later"
	stamps_box = VBoxContainer.new()
	stamps_box.add_theme_constant_override("separation", 3)
	col.add_child(stamps_box)
	_rebuild_stamps()

	_section(col, "Problems")
	var prow := _flow(col)
	_mini(prow, "SCAN", scan_problems, false).tooltip_text = "Find overlapping pieces, mismatched banks and water with no bank"
	_mini(prow, "NEXT PROBLEM", next_problem, false).tooltip_text = "Fly the view to the next problem"
	_mini(prow, "CLEAR FLAGS", clear_problem_flags, false)

	var layers_from := col.get_child_count()
	_section(col, "Layers  (hide to see through, lock to keep from moving)")
	for nm: String in layer_names():
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 4)
		col.add_child(lrow)
		var lab := Label.new()
		lab.text = nm
		lab.clip_text = true
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_font_size_override("font_size", 11)
		lrow.add_child(lab)
		var hb := _mini(lrow, "HIDE", func(): set_layer_hidden(nm, not bool(placed.hidden_types.get(nm, false))))
		var lb := _mini(lrow, "LOCK", func(): set_layer_locked(nm, not bool(placed.locked_types.get(nm, false))))
		hb.size_flags_horizontal = Control.SIZE_SHRINK_END
		lb.size_flags_horizontal = Control.SIZE_SHRINK_END
		_layer_buttons[nm] = {"hide": hb, "lock": lb}
	var old_layers: Array = []
	for i in range(layers_from, col.get_child_count()):
		old_layers.append(col.get_child(i))
	_ui["old_layers"] = old_layers  # the black map editor shows these in its right sidebar instead
	set_pro_tools_open(MapEditorMode.active())


func set_pro_tools_open(on: bool) -> void:
	if tools_body == null:
		return
	tools_body.visible = on
	tools_toggle.text = "AUTO-TILE & TOOLS  ^" if on else "AUTO-TILE & TOOLS  v"


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
	for t: String in _terrain_buttons:
		if t == "_fix":
			(_terrain_buttons[t] as Button).set_pressed_no_signal(erase_autofix)
		else:
			(_terrain_buttons[t] as Button).set_pressed_no_signal(tool == "terrain" and auto_terrain == t)
	for sh: String in _shape_buttons:
		(_shape_buttons[sh] as Button).set_pressed_no_signal(shape == sh)
	if bank_button != null:
		bank_button.text = "BANK LOOK: %s" % str(BANK_LABELS.get(bank_family, "AUTO"))
	for nm: String in _layer_buttons:
		(_layer_buttons[nm].hide as Button).set_pressed_no_signal(bool(placed.hidden_types.get(nm, false)))
		(_layer_buttons[nm].lock as Button).set_pressed_no_signal(bool(placed.locked_types.get(nm, false)))
	if brush_button != null:
		brush_button.text = "BRUSH  %d x %d" % [brush, brush]
		brush_button.set_pressed_no_signal(false)
	if browser != null:
		browser.sync()
	if hud_snap_button != null:
		var hs: int = hud_bar().hud_snap if hud_bar() != null else 0
		hud_snap_button.text = "HUD GRID  %s" % (str(hs) if hs > 0 else "OFF")
	snap_button.text = "GRASS GRID" if snap > 0 and _grass_tool() else "SNAP  %s" % (str(snap) if snap > 0 else "OFF")
	clear_button.text = "SURE?" if _clear_armed else "CLEAR ALL"
	reset_button.text = "SURE?" if _reset_armed else "RESET"
	var hud := hud_bar()
	for id: String in _hud_buttons:
		(_hud_buttons[id] as Button).set_pressed_no_signal(hud != null and hud.selected_element == id)
	inspector.visible = not selected.is_empty() or (properties != null and not selection.is_empty())
	if properties != null:
		properties.refresh()
	if not selected.is_empty():
		inspector_name.text = str(PlacedObjects.def_of(selected.id).label)
		inspector_pos.text = "X %d   Y %d" % [int(selected.pos.x), int(selected.pos.y)]
	var what := ("Terrain: %s  (%s)" % [("clear floor" if auto_terrain == "" else auto_terrain), shape]) if tool == "terrain" else "Box select: drag a box" if tool == "box" else "Stamp: click to drop (%d pieces)" % clipboard.size() if tool == "stamp" else "Painting: %s  (drag to lay tiles, %d x %d brush)" % [str(PlacedObjects.def_of(place_id).label), brush, brush] if tool == "paint" else "Placing: %s" % str(PlacedObjects.def_of(place_id).label) if tool == "place" else ("Erase mode" if tool == "erase" else "Pan: drag the map" if tool == "pan" else "Select / move")
	count_label.text = "%d objects" % placed.objects.size()
	status.text = _note if Time.get_ticks_msec() < _note_until else what
