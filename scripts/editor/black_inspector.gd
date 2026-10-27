class_name BlackInspector
extends VBoxContainer

## Editor layers, in panel order. Keys are shared with PlacedObjects.set_editor_layer_visible/locked.
const LAYERS: Array[String] = ["Ground", "Ground details", "Paths", "Water", "Cliffs", "Structures", "Props", "Shrines", "Entities"]
const THUMB := 48

var editor: WorldEditor
var placed: PlacedObjects

var _object_box: VBoxContainer
var _thumb: TextureRect
var _name: Label
var _id: Label
var _layer: Label
var _collision: Label
var _pos_row: HBoxContainer
var _x: SpinBox
var _y: SpinBox
var _rotate: Button
var _multi: Label
var _layer_rows: Dictionary = {}  ## layer -> {"hide": Button, "lock": Button}
var _target: Dictionary = {}
var _dirty := false


func setup(e: WorldEditor) -> void:
	editor = e
	placed = e.placed
	if get_child_count() == 0:
		_build()
	update_state()


## Which editor layer an object id belongs to ("" for an unknown id). Static so PlacedObjects can call it
## without depending on the inspector instance.
static func group_of(id: String) -> String:
	var def := PlacedObjects.def_of(id)
	if def.is_empty():
		return ""
	var kind := str(def.get("kind", ""))
	match kind:
		"spawn", "bandit", "pickup":
			return "Entities"
		"dynamic_shrine":
			return "Shrines"
		"water_fx":
			return "Water"
		"bridge", "block":
			return "Structures"
		"tree", "ashen_tree", "blight_light", "fireflies", "ashen_fire":
			return "Props"
		"grass":
			return "Ground details" if bool(def.get("tall", false)) else "Ground"
		"ground":
			if def.has("shore_mask"):
				return "Ground" if int(def.shore_mask) == 15 else "Water"
			if def.has("water_role"):
				return "Water"
			return "Paths" if id.begins_with("ground9_") else "Ground"
		"wall":
			if id == "ancient_shrine":
				return "Shrines"
			if bool(def.get("walkable", false)) or id.begins_with("cliff_"):
				return "Cliffs"
			if bool(def.get("rock", false)):
				return "Props"
			return "Structures"
	return "Props"


## Use the browser's catalog-facing partners for placed objects too.
static func rotation_partner(id: String) -> String:
	return BlackAssetBrowser.rotate_partner(id)


## Read-only description of the colliders the object really built (walked from its live nodes).
static func collision_info(obj: Dictionary) -> String:
	var def := PlacedObjects.def_of(str(obj.get("id", "")))
	var lines: Array[String] = []
	if bool(def.get("walkable", false)):
		lines.append("Walkable (no wall collider)")
		if def.has("rise"):
			lines.append("Ramp rise %d px" % int(def.rise))
	for node: Variant in obj.get("nodes", []):
		if not is_instance_valid(node):
			continue
		var n := node as Node
		var found: Array[Node] = []
		if n is CollisionShape2D or n is CollisionPolygon2D:
			found.append(n)
		found.append_array(n.find_children("*", "CollisionShape2D", true, false))
		found.append_array(n.find_children("*", "CollisionPolygon2D", true, false))
		for c: Node in found:
			var text := _shape_text(c)
			if text != "":
				lines.append(text)
	if lines.is_empty():
		return "None (walk-through)"
	return "\n".join(lines)


static func _shape_text(c: Node) -> String:
	if c is CollisionPolygon2D:
		var poly := (c as CollisionPolygon2D).polygon
		return "Polygon %d pts" % poly.size() + _bounds_text(poly)
	var shape := (c as CollisionShape2D).shape
	if shape == null or (c as CollisionShape2D).disabled:
		return ""
	if shape is RectangleShape2D:
		var s := (shape as RectangleShape2D).size
		return "Box %d x %d" % [int(round(s.x)), int(round(s.y))]
	if shape is ConvexPolygonShape2D:
		var pts := (shape as ConvexPolygonShape2D).points
		return "Polygon %d pts" % pts.size() + _bounds_text(pts)
	if shape is CircleShape2D:
		return "Circle r %d" % int(round((shape as CircleShape2D).radius))
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		return "Capsule r %d h %d" % [int(round(cap.radius)), int(round(cap.height))]
	return shape.get_class()


static func _bounds_text(pts: PackedVector2Array) -> String:
	if pts.is_empty():
		return ""
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return ", %d x %d" % [int(round(r.size.x)), int(round(r.size.y))]


## Live selection from the editor, minus anything no longer in placed.objects (freed by undo / redo / delete).
func selected_list() -> Array:
	return editor.selected_objects().filter(func(o: Variant) -> bool: return o is Dictionary and placed.objects.has(o))


func update_state() -> void:
	if editor == null or _object_box == null:
		return
	var sel := selected_list()
	var prev := _target
	_target = sel[0] if sel.size() == 1 else {}
	var same := not _target.is_empty() and is_same(prev, _target)
	_object_box.visible = not sel.is_empty()
	_multi.visible = sel.size() > 1
	for c: Control in [_thumb, _name, _id, _layer, _collision, _pos_row]:
		c.visible = not _target.is_empty()
	_rotate.visible = false
	if sel.size() > 1:
		var groups := {}
		for o: Dictionary in sel:
			groups[group_of(str(o.id))] = true
		_multi.text = "%d objects selected\nLayers: %s" % [sel.size(), ", ".join(groups.keys())]
	if _target.is_empty():
		_dirty = false
	else:
		var id := str(_target.id)
		var def := PlacedObjects.def_of(id)
		_thumb.texture = _thumbnail(id)
		_name.text = str(def.get("label", id))
		_id.text = "ID  %s" % id
		_layer.text = "Layer  %s  (%s)" % [group_of(id), PlacedObjects.type_of(id)]
		var fp := PlacedObjects.footprint_rect(id, _target.pos).size
		_collision.text = "Footprint %d x %d\nCollision  %s" % [int(round(fp.x)), int(round(fp.y)), collision_info(_target)]
		var locked := placed.type_locked(id)
		_x.editable = not locked
		_y.editable = not locked
		_sync_spins(not same)
		var partner := rotation_partner(id)
		if partner != "":
			_rotate.visible = true
			_rotate.disabled = locked
			_rotate.text = "ROTATE  ->  %s" % partner
			_rotate.tooltip_text = "Swaps to \"%s\" at the same ground anchor point (X/Y kept). The art's own anchor comes from that catalog piece, so the picture shifts around the anchor." % str(PlacedObjects.def_of(partner).label)
	for nm: String in _layer_rows:
		(_layer_rows[nm].hide as Button).set_pressed_no_signal(bool(placed.editor_hidden_layers.get(nm, false)))
		(_layer_rows[nm].lock as Button).set_pressed_no_signal(bool(placed.editor_locked_layers.get(nm, false)))


func _process(_d: float) -> void:
	if is_visible_in_tree() and not _target.is_empty():
		if not placed.objects.has(_target):
			update_state()
		else:
			_sync_spins(false)


## Mirror the object's position into the boxes unless the user is mid-edit.
func _sync_spins(force: bool) -> void:
	if _target.is_empty():
		return
	if not force and (_dirty or _x.get_line_edit().has_focus() or _y.get_line_edit().has_focus()):
		return
	var p: Vector2 = _target.pos
	if force or not is_equal_approx(_x.value, round(p.x)) or not is_equal_approx(_y.value, round(p.y)):
		_x.set_value_no_signal(round(p.x))
		_y.set_value_no_signal(round(p.y))
	_dirty = false


func _thumbnail(id: String) -> Texture2D:
	var b: Variant = editor._palette_buttons.get(id)
	if b is Button and (b as Button).icon != null:
		return (b as Button).icon
	var tex: Variant = PlacedObjects.art_texture(id, Vector2.ZERO)[0]
	if tex is Texture2D:
		return tex
	return WorldEditor.block_icon(id) if str(PlacedObjects.def_of(id).get("kind", "")) == "block" else null


func commit_position() -> bool:
	if _target.is_empty() or not _dirty:
		return false
	_dirty = false
	var obj := _target
	if not placed.objects.has(obj):
		update_state()
		return false
	var cur: Vector2 = obj.pos
	# Untouched axes keep their exact (possibly fractional) value instead of the box's rounded one.
	var nx := cur.x if is_equal_approx(_x.value, round(cur.x)) else _x.value
	var ny := cur.y if is_equal_approx(_y.value, round(cur.y)) else _y.value
	var to := Vector2(nx, ny)
	if to.is_equal_approx(cur):
		_sync_spins(true)
		return false
	if placed.type_locked(obj.id):
		editor._flash("That layer is locked")
	elif not placed.can_place(obj.id, to):
		editor._flash("Can't move there (out of bounds or too close to someone)")
	else:
		placed.move(obj, to)
		editor._refresh()
		update_state()
		return true
	_sync_spins(true)
	return false


func rotate_selected() -> bool:
	var obj := _target
	if obj.is_empty() or not placed.objects.has(obj):
		return false
	var partner := rotation_partner(str(obj.id))
	var pos: Vector2 = obj.pos
	if partner == "" or placed.type_locked(obj.id) or placed.type_locked(partner):
		return false
	if not placed.can_place(partner, pos):
		editor._flash("Can't rotate here")
		return false
	placed.remove(obj, false)
	var made := placed.add(partner, pos, false)
	if made.is_empty():
		placed.add(str(obj.id), pos, false)
		placed._changed()
		editor._flash("Rotate failed")
		return false
	if bool(PlacedObjects.def_of(partner).get("walkable", false)) or bool(PlacedObjects.def_of(str(obj.id)).get("walkable", false)):
		placed.link_stair_zones()
	placed._changed()  # remove + add flush as ONE undo step
	_replace_in_selection(obj, made)
	editor._refresh()
	update_state()
	return true


func _replace_in_selection(old: Dictionary, now: Dictionary) -> void:
	editor.selected = now
	editor.dragging = false
	var i := editor.selection.find(old)
	if i >= 0:
		editor.selection[i] = now


func set_layer_visible(layer: String, shown: bool) -> void:
	placed.set_editor_layer_visible(layer, shown)
	if not shown and editor.place_id != "" and group_of(editor.place_id) == layer and editor.tool in ["place", "paint", "terrain"]:
		editor.set_tool("select")
	_after_layer_change()


func set_layer_locked(layer: String, locked: bool) -> void:
	placed.set_editor_layer_locked(layer, locked)
	_after_layer_change()


func _after_layer_change() -> void:
	_prune_selection()
	editor._refresh()
	update_state()


## Drop anything that is now hidden or locked (or already gone) from every selection the editor holds.
func _prune_selection() -> void:
	var keep := func(o: Variant) -> bool: return o is Dictionary and placed.objects.has(o) and placed.type_visible(o.id) and not placed.type_locked(o.id)
	editor.selection = editor.selection.filter(keep)
	if not editor.selected.is_empty() and not keep.call(editor.selected):
		editor.selected = {}
		editor.dragging = false


func _build() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_object_box = VBoxContainer.new()
	_object_box.add_theme_constant_override("separation", 4)
	add_child(_object_box)
	_section(_object_box, "Object")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_object_box.add_child(head)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_thumb)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(txt)
	_name = _label(txt, 14, Color.WHITE)
	_id = _label(txt, 11, WorldEditor.MUTED)
	_multi = _label(_object_box, 12, Color.WHITE)
	_layer = _label(_object_box, 11, WorldEditor.MUTED)
	_pos_row = HBoxContainer.new()
	_pos_row.add_theme_constant_override("separation", 4)
	_object_box.add_child(_pos_row)
	_x = _spin(_pos_row, "X")
	_y = _spin(_pos_row, "Y")
	_collision = _label(_object_box, 11, WorldEditor.MUTED)
	_rotate = editor._mini(_object_box, "ROTATE", rotate_selected, false)
	_section(self, "Layers")
	for nm: String in LAYERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		add_child(row)
		var lab := _label(row, 12, Color.WHITE)
		lab.text = nm
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.clip_text = true
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hide := _layer_toggle(row, "HIDE", func(): set_layer_visible(nm, not (_layer_rows[nm].hide as Button).button_pressed))
		var lock := _layer_toggle(row, "LOCK", func(): set_layer_locked(nm, (_layer_rows[nm].lock as Button).button_pressed))
		_layer_rows[nm] = {"hide": hide, "lock": lock}


func _section(parent: Control, title: String) -> void:
	editor._section(parent, title)


func _label(parent: Node, font: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(40, 0)
	parent.add_child(l)
	return l


func _spin(parent: Node, axis: String) -> SpinBox:
	var l := _label(parent, 11, WorldEditor.MUTED)
	l.text = axis
	l.custom_minimum_size = Vector2.ZERO
	var s := SpinBox.new()
	s.step = 1.0
	s.allow_greater = true
	s.allow_lesser = true
	s.min_value = -100000.0
	s.max_value = 100000.0
	s.select_all_on_focus = true
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(60, 0)
	s.tooltip_text = "Press Enter or click away to apply (one undo step)"
	# value_changed only marks the edit pending: the move is committed on Enter or focus exit, never per tick.
	s.value_changed.connect(func(_v: float): _dirty = true)
	s.get_line_edit().text_submitted.connect(func(_t: String):
		s.apply()
		commit_position())
	s.get_line_edit().focus_exited.connect(func():
		s.apply()
		commit_position())
	parent.add_child(s)
	return s


func _layer_toggle(parent: Node, text: String, cb: Callable) -> Button:
	var b := editor._mini(parent, text, cb, true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(54 if text == "LOCK" else 46, 26)
	return b
