class_name EditorMinimap
extends Control
## Map editor minimap: the whole arena drawn from the real placed objects, with the visible part of the canvas outlined.
## Click or drag on it to move the view there. Hidden layers are left out, like on the canvas.

const W := 220.0
const BG_COLOR := Color("#0a0a0a")

var editor: WorldEditor
var bounds := Rect2()
var _img: Image
var _tex: ImageTexture
var _last_total := -1
var _last_hidden := ""
var _dragging := false
var _since_build := 0


func setup(ed: WorldEditor) -> void:
	editor = ed
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	bounds = ed.arena.bounds if ed.arena != null else Rect2(-2000, -2000, 4000, 4000)
	var h := clampf(W * bounds.size.y / maxf(bounds.size.x, 1.0), 90.0, 220.0)
	custom_minimum_size = Vector2(W, h)
	size = Vector2(W, h)
	_img = Image.create(int(W), int(h), false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	tooltip_text = "Minimap: click or drag to move the view (M hides it)"
	rebuild()


## Where a world point lands on the minimap (0..size).
func to_map(world: Vector2) -> Vector2:
	return (world - bounds.position) / bounds.size * size


func to_world(local: Vector2) -> Vector2:
	return bounds.position + local / size * bounds.size


static func color_for(id: String) -> Color:
	var def: Dictionary = PlacedObjects.def_of(id)
	var kind := str(def.get("kind", ""))
	if def.has("water_role") or kind == "water_fx":
		return Color("#3a86a8")
	match kind:
		"grass":
			return Color("#4f6b3c")
		"ground":
			return Color("#6b5a45")
		"tree", "ashen_tree":
			return Color("#8f7aa8")
		"bandit":
			return Color("#d05050")
		"spawn":
			return Color("#ffffff")
		"pickup":
			return Color("#d8c060")
		"wall", "block":
			return Color("#9a9aa2")
		"bridge":
			return Color("#a58b64")
	return Color("#c8c8c8")


## Repaint the picture from the placed objects: floor first, then everything standing on it.
func rebuild() -> void:
	if editor == null or _img == null:
		return
	_img.fill(BG_COLOR)
	var ph: PlacedObjects = editor.placed
	for pass_floor in [true, false]:
		for o: Dictionary in ph.objects:
			var id := str(o.id)
			if PlacedObjects.is_floor_tile(id) != pass_floor or not ph.type_visible(id):
				continue
			var r := PlacedObjects.footprint_rect(id, o.pos)
			var a := to_map(r.position)
			var b := to_map(r.end)
			var rect := Rect2i(int(floor(a.x)), int(floor(a.y)), maxi(1, int(ceil(b.x - a.x))), maxi(1, int(ceil(b.y - a.y))))
			rect = rect.intersection(Rect2i(0, 0, _img.get_width(), _img.get_height()))
			if rect.size.x > 0 and rect.size.y > 0:
				_img.fill_rect(rect, color_for(id))
	_tex.update(_img)
	_last_total = ph.objects.size()
	_last_hidden = str(ph.hidden_types)
	_since_build = 0
	queue_redraw()


## Called every frame by the shell: repaints when the map changed, and redraws the view outline.
func tick() -> void:
	if not visible or editor == null:
		return
	_since_build += 1
	if editor.placed.objects.size() != _last_total or str(editor.placed.hidden_types) != _last_hidden or _since_build >= 45:
		if _since_build >= 6:  # throttle while painting a long stroke
			rebuild()
	queue_redraw()


## The part of the world the canvas shows right now.
func view_world_rect() -> Rect2:
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var cr: Rect2 = editor.shell.canvas_rect() if editor.shell != null else vp.get_visible_rect()
	var a: Vector2 = inv * cr.position
	var b: Vector2 = inv * cr.end
	return Rect2(a, b - a).abs()


func _draw() -> void:
	if _tex == null:
		return
	draw_texture(_tex, Vector2.ZERO)
	var vr := view_world_rect()
	var a := to_map(vr.position)
	var b := to_map(vr.end)
	var box := Rect2(a, b - a).intersection(Rect2(Vector2.ZERO, size))
	if box.size.x > 1.0 and box.size.y > 1.0:
		draw_rect(box, Color(1, 1, 1, 0.12), true)
		draw_rect(box, Color("#F5F5F5"), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), WorldEditor.EDGE, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			_goto((event as InputEventMouseButton).position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_goto((event as InputEventMouseMotion).position)
		accept_event()


func _goto(local: Vector2) -> void:
	editor.center_on(to_world(local.clamp(Vector2.ZERO, size)))
