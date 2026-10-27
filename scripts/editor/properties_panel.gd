class_name PropertiesPanel
extends VBoxContainer
## Map editor Properties card: what is selected, where it is (editable X / Y), its size, and DUPLICATE / DELETE.
## Everything goes through the editor's real move / add / delete, so each change is one undo step.

var editor: WorldEditor
var icon: TextureRect
var title: Label
var layer_label: Label
var size_label: Label
var x_field: SpinBox
var y_field: SpinBox
var note: Label
var btn_dup: Button
var btn_del: Button
var pos_row: Control
var _syncing := false
var _shown_obj: Variant = null


func setup(ed: WorldEditor) -> void:
	editor = ed
	name = "PropertiesPanel"
	add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("#F5F5F5"))
	title.clip_text = true
	names.add_child(title)
	layer_label = Label.new()
	layer_label.add_theme_font_size_override("font_size", 11)
	layer_label.add_theme_color_override("font_color", WorldEditor.MUTED)
	layer_label.clip_text = true
	names.add_child(layer_label)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	add_child(prow)
	pos_row = prow
	x_field = _field(prow, "X")
	y_field = _field(prow, "Y")
	size_label = Label.new()
	size_label.add_theme_font_size_override("font_size", 11)
	size_label.add_theme_color_override("font_color", WorldEditor.MUTED)
	add_child(size_label)
	note = Label.new()
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", WorldEditor.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	add_child(brow)
	btn_dup = _button(brow, "DUPLICATE", duplicate_pressed, "Drop a copy next to it and select the copy")
	btn_del = _button(brow, "DELETE", editor.delete_selected, "Delete the selection (Del)")
	editor._skin(btn_del, "danger")
	btn_del.add_theme_font_size_override("font_size", 12)
	refresh()


func _field(parent: Node, label: String) -> SpinBox:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", WorldEditor.MUTED)
	parent.add_child(l)
	var s := SpinBox.new()
	s.min_value = -100000
	s.max_value = 100000
	s.step = 1
	s.allow_greater = true
	s.allow_lesser = true
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(func(_v: float) -> void: apply_position())
	parent.add_child(s)
	return s


func _button(parent: Node, text: String, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	editor._skin(b)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func duplicate_pressed() -> void:
	editor.duplicate_selected()


## Typed X / Y -> the real move. A refused move (blocked, out of bounds, locked layer) puts the numbers back.
func apply_position() -> void:
	if _syncing or editor.selected.is_empty():
		return
	editor.move_selected_to(Vector2(x_field.value, y_field.value))
	refresh()


func refresh() -> void:
	if editor == null or title == null:
		return
	var sel := editor.selected_objects()
	var many := editor.selection.size() > 1 or (editor.selected.is_empty() and not editor.selection.is_empty())
	_syncing = true
	if sel.is_empty():
		_syncing = false
		return
	if many:
		title.text = "%d objects selected" % sel.size()
		layer_label.text = "Group selection"
		icon.texture = null
		pos_row.visible = false
		size_label.text = ""
		note.text = "Drag to move the group. Delete removes it; COPY / PASTE in AUTO-TILE & TOOLS."
		btn_dup.visible = false
		btn_del.disabled = false
		_syncing = false
		return
	var obj: Dictionary = sel[0]
	var id := str(obj.id)
	var def: Dictionary = PlacedObjects.def_of(id)
	title.text = str(def.get("label", id))
	layer_label.text = "Layer: " + PlacedObjects.type_of(id)
	var pb := editor._palette_buttons.get(id) as Button
	icon.texture = pb.icon if pb != null else null
	pos_row.visible = true
	var locked := editor.placed.type_locked(id)
	if obj != _shown_obj or not (x_field.get_line_edit().has_focus() or y_field.get_line_edit().has_focus()):
		x_field.set_value_no_signal(roundf(obj.pos.x))
		y_field.set_value_no_signal(roundf(obj.pos.y))
	_shown_obj = obj
	x_field.editable = not locked
	y_field.editable = not locked
	var fp := PlacedObjects.footprint_of(id)
	size_label.text = "Footprint  %d x %d" % [int(fp.x), int(fp.y)]
	note.text = "This layer is locked. Unlock it to move or delete." if locked else ("Floor tiles snap to the floor grid." if PlacedObjects.is_floor_tile(id) else "")
	note.visible = note.text != ""
	btn_dup.visible = str(def.get("kind", "")) != "spawn"
	btn_dup.disabled = locked
	btn_del.disabled = locked or str(def.get("kind", "")) == "spawn"
	_syncing = false
