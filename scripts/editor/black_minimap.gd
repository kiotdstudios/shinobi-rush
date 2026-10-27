class_name BlackMinimap
extends Control
## A live miniature of the current map: every placed object's own art drawn at its scaled world bounds,
## a camera outline for what the canvas shows, and click/drag to move the camera there.
## Draws straight from PlacedObjects data -- never a SubViewport, so the game is not simulated twice.

const INSET := 6.0
const POLL_MSEC := 300
const BACKGROUND := Color(0.035, 0.035, 0.04, 1.0)
const BORDER := Color(1, 1, 1, 0.55)
const CAMERA_OUTLINE := Color(1, 1, 1, 0.95)
const PLACEHOLDER := Color(0.42, 0.42, 0.45, 0.9)

var editor: Node = null
var world_bounds := Rect2(0, 0, 1, 1)
## Drawn in order: floor tiles first, then props y-sorted. Each entry {tex: Texture2D|null, rect: Rect2 (world)}.
var entries: Array = []

var _signature := 0
var _next_poll := 0
var _view_rect := Rect2()
var _dragging := false
var _overlay: Control


func setup(e: Node) -> void:
	editor = e
	refresh_map()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS  # the builder pauses the world; the map must keep tracking it
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay = Control.new()
	_overlay.name = "CameraOutline"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		if _overlay != null:
			_overlay.queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var now := Time.get_ticks_msec()
	if now >= _next_poll:
		_next_poll = now + POLL_MSEC
		var sig := _current_signature()
		if sig != _signature:
			_rebuild(sig)
	var view := view_world_rect()
	if view != _view_rect:
		_view_rect = view
		if _overlay != null:
			_overlay.queue_redraw()


func refresh_map() -> void:
	_rebuild(_current_signature())


# ------------------------------------------------------------------ data

func _placed() -> PlacedObjects:
	if editor == null or not is_instance_valid(editor):
		return null
	return editor.get("placed") as PlacedObjects


func _arena_bounds() -> Rect2:
	var arena: Variant = editor.get("arena") if editor != null and is_instance_valid(editor) else null
	if arena is TrainingArena and is_instance_valid(arena):
		return (arena as TrainingArena).bounds
	return Rect2()


## Cheap change detector. Prefers a `revision` counter on PlacedObjects when one exists; otherwise hashes
## the object count, ids and positions. Layer visibility and arena bounds are always folded in.
func _current_signature() -> int:
	var p := _placed()
	var h := hash([_arena_bounds(), p.hidden_types, p.editor_hidden_layers] if p != null else [_arena_bounds()])
	if p == null:
		return h
	if p.has_method("get_revision"):
		return hash([h, p.call("get_revision"), p.objects.size()])
	h = hash([h, p.objects.size()])
	for o: Dictionary in p.objects:
		var pos: Vector2 = o.pos
		h = (h * 31 + String(o.id).hash()) & 0x7fffffffffff
		h = (h * 31 + int(pos.x * 4.0) * 73856093 + int(pos.y * 4.0) * 19349663) & 0x7fffffffffff
	return h


func _rebuild(sig: int) -> void:
	_signature = sig
	var floor_items: Array = []
	var props: Array = []
	var p := _placed()
	var bounds := _arena_bounds()
	if p != null:
		for o: Dictionary in p.objects:
			var id := String(o.id)
			if not p.type_visible(id):
				continue
			var pos: Vector2 = o.pos
			var at := PlacedObjects.art_texture(id, pos)
			var tex: Texture2D = at[0]
			var rect: Rect2
			if tex != null:
				rect = Rect2(at[1] as Vector2, tex.get_size())
			else:
				rect = PlacedObjects.art_rect(id, pos)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			var item := {"tex": tex, "rect": rect, "y": pos.y}
			if PlacedObjects.is_floor_tile(id):
				floor_items.append(item)
			else:
				props.append(item)
			bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	entries = floor_items + props
	world_bounds = bounds if bounds.size.x > 0.0 and bounds.size.y > 0.0 else Rect2(0, 0, 1, 1)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


# ------------------------------------------------------------------ mapping

## The inset, aspect-fitted area of this control the world is drawn into.
func map_rect() -> Rect2:
	var area := Rect2(Vector2(INSET, INSET), (size - Vector2(INSET, INSET) * 2.0).max(Vector2.ONE))
	var s := map_scale()
	var fitted := world_bounds.size * s
	return Rect2(area.position + (area.size - fitted) * 0.5, fitted)


func map_scale() -> float:
	var area := (size - Vector2(INSET, INSET) * 2.0).max(Vector2.ONE)
	return minf(area.x / maxf(world_bounds.size.x, 1.0), area.y / maxf(world_bounds.size.y, 1.0))


func world_to_map(world: Vector2) -> Vector2:
	return map_rect().position + (world - world_bounds.position) * map_scale()


func map_to_world(local: Vector2) -> Vector2:
	return world_bounds.position + (local - map_rect().position) / map_scale()


# ------------------------------------------------------------------ camera

func _camera() -> Camera2D:
	if editor != null and is_instance_valid(editor) and editor.has_method("_camera"):
		var c: Camera2D = editor.call("_camera")
		if c != null:
			return c
	return get_viewport().get_camera_2d() if is_inside_tree() else null


## The screen region the world canvas shows: the shell's centre canvas when it reports one, else the full viewport.
func canvas_screen_rect() -> Rect2:
	var shell: Variant = editor.get("black_shell") if editor != null and is_instance_valid(editor) else null
	if shell is Object and is_instance_valid(shell) and (shell as Object).has_method("canvas_rect"):
		var r: Variant = (shell as Object).call("canvas_rect")
		if r is Rect2 and (r as Rect2).size.x > 0.0 and (r as Rect2).size.y > 0.0:
			return r
	return get_viewport().get_visible_rect() if is_inside_tree() else Rect2()


## The world rectangle currently visible in the canvas region.
func view_world_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var screen := canvas_screen_rect()
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a := inv * screen.position
	var b := inv * screen.end
	return Rect2(a, Vector2.ZERO).expand(b)


## Moves the camera so the canvas region is centred on `world`. Returns false with no camera.
func navigate_to(world: Vector2) -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var view := view_world_rect()
	var full := get_viewport().get_visible_rect()
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	# The shell's canvas may not sit at the screen centre: aim the canvas centre, not the screen centre.
	var focus := cam.get_screen_center_position() + (view.get_center() - inv * full.get_center())
	cam.offset += world - focus
	cam.force_update_scroll()
	_view_rect = view_world_rect()
	if _overlay != null:
		_overlay.queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			navigate_to(map_to_world((event as InputEventMouseButton).position))
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		navigate_to(map_to_world((event as InputEventMouseMotion).position))
		accept_event()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var s := map_scale()
	for e: Dictionary in entries:
		var r: Rect2 = e.rect
		var dest := Rect2(world_to_map(r.position), r.size * s)
		var tex: Texture2D = e.tex
		if tex != null:
			draw_texture_rect(tex, dest, false)
		else:
			draw_rect(dest, PLACEHOLDER)


func _draw_overlay() -> void:
	_overlay.draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), BORDER, false, 1.0)
	if _view_rect.size == Vector2.ZERO:
		return
	var outline := Rect2(world_to_map(_view_rect.position), _view_rect.size * map_scale())
	var clipped := outline.intersection(Rect2(Vector2.ONE, size - Vector2(2, 2)))
	if clipped.size.x > 0.0 and clipped.size.y > 0.0:
		_overlay.draw_rect(clipped, CAMERA_OUTLINE, false, 1.5)
