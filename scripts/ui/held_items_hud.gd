class_name HeldItemsHud
extends CanvasLayer
## Owner 2026-10-25: "high quality procedural inventory UI with selecting, dropping, and rearranging
## inventory and held items D pad slots", toggled by the PS4 controller's touchpad ("black pad") --
## see `inventory_toggle` in project.godot (JOY_BUTTON_TOUCHPAD / key I).
##
## Two pieces, both pure presentation over PlayerController.held_items (a HeldItems):
##  1. The diamond quick-slot readout (always visible, bottom-right): one swatch per D-pad direction
##     (UP/RIGHT/DOWN/LEFT), each with a procedurally-drawn icon (no art asset exists for a throwable
##     kunai or for paper tags) and an "xN" count badge, styled after the reference the owner shared.
##  2. The full inventory screen (toggled, centre panel): every item with its count, a yellow
##     SELECT highlight, UP/DOWN buttons to REARRANGE which D-pad direction it occupies, and a DROP
##     button that discards one. All procedural StyleBoxFlat/Label/Button, matching this project's
##     existing UI convention (SettingsPanel, DebugHud) rather than pixel art.

const DIAMOND_CENTER := Vector2(1180.0, 560.0)  ## PROVISIONAL: bottom-right, clear of the centre ability bar (HealthBar, y=616) and the bottom-edge dock tabs
const SLOT_REACH := 46.0  ## PROVISIONAL: centre-to-slot distance
const SLOT_SIZE := 40.0
const DIR_OFFSETS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]  ## UP, RIGHT, DOWN, LEFT -- matches HeldItems.order
const PANEL_SIZE := Vector2(360.0, 260.0)
const ROW_H := 44.0
const COLOR_BG := Color(0.04, 0.04, 0.04, 0.92)
const COLOR_BORDER := Color("#9AA0A6")
const COLOR_SELECTED := Color(1.0, 0.85, 0.2, 0.9)
const COLOR_EMPTY_COUNT := Color(1.0, 1.0, 1.0, 0.45)

var _player: PlayerController
var _diamond: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var open := false
var selected_slot := 0  ## index into held_items.order currently highlighted in the panel


func bind(player: PlayerController) -> void:
	_player = player
	_build_diamond()
	_build_panel()


func _build_diamond() -> void:
	_diamond = Control.new()
	_diamond.name = "HeldItemsDiamond"
	_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diamond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_diamond)
	_diamond.draw.connect(_draw_diamond)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "InventoryPanel"
	_panel.visible = false
	_panel.position = Vector2(640.0, 360.0) - PANEL_SIZE * 0.5
	_panel.custom_minimum_size = PANEL_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)
	var title := Label.new()
	title.text = "ITEMS  (I / touchpad to close -- UP/DOWN moves a slot, DROP discards one)"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", COLOR_BORDER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	outer.add_child(_rows)
	_rebuild_rows()


func _rebuild_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	if _player == null:
		return
	var items := _player.held_items
	for i in items.order.size():
		_rows.add_child(_make_row(i))


func _make_row(slot_index: int) -> Control:
	var items := _player.held_items
	var item_id: String = items.order[slot_index]
	var row := HBoxContainer.new()
	row.name = "Row%d" % slot_index
	row.custom_minimum_size = Vector2(0, ROW_H)
	var select := Button.new()
	select.text = "%s  %s  x%d" % [["UP", "RIGHT", "DOWN", "LEFT"][slot_index], items.label(item_id), items.count(item_id)]
	select.toggle_mode = true
	select.button_pressed = (slot_index == selected_slot)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.focus_mode = Control.FOCUS_NONE
	_style_row_button(select, items.color(item_id), slot_index == selected_slot)
	select.pressed.connect(func() -> void:
		selected_slot = slot_index
		_rebuild_rows())
	row.add_child(select)
	var up := Button.new()
	up.text = "UP"
	up.focus_mode = Control.FOCUS_NONE
	up.add_theme_font_size_override("font_size", 10)
	up.pressed.connect(func() -> void: _rearrange(slot_index, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "DOWN"
	down.focus_mode = Control.FOCUS_NONE
	down.add_theme_font_size_override("font_size", 10)
	down.pressed.connect(func() -> void: _rearrange(slot_index, 1))
	row.add_child(down)
	var drop := Button.new()
	drop.text = "DROP"
	drop.focus_mode = Control.FOCUS_NONE
	drop.add_theme_font_size_override("font_size", 10)
	drop.disabled = items.count(item_id) <= 0
	drop.pressed.connect(func() -> void:
		items.drop(item_id, 1)
		_rebuild_rows())
	row.add_child(drop)
	return row


## Swaps the slot at `slot_index` with its neighbour `dir` steps away (-1 = up a row, +1 = down a row).
func _rearrange(slot_index: int, dir: int) -> void:
	var items := _player.held_items
	var other := slot_index + dir
	if other < 0 or other >= items.order.size():
		return
	items.swap_slots(slot_index, other)
	if selected_slot == slot_index:
		selected_slot = other
	elif selected_slot == other:
		selected_slot = slot_index
	_rebuild_rows()


func _process(_delta: float) -> void:
	if _player == null:
		return
	# Toggle only -- actually USING an item (use_item_1..4) is gameplay input and is polled by
	# PlayerController itself in _physics_process, same as dodge/jump/attack. This node is display +
	# the inventory screen's own buttons only.
	if Input.is_action_just_pressed("inventory_toggle"):
		set_open(not open)
	if open:
		_rebuild_rows()  # cheap (4 rows): keeps counts live while the panel is open
	else:
		_diamond.queue_redraw()

func set_open(v: bool) -> void:
	open = v
	if _panel != null:
		_panel.visible = v
	if v:
		_rebuild_rows()


func _style_row_button(b: Button, item_color: Color, selected: bool) -> void:
	var edge := COLOR_SELECTED if selected else item_color
	var bg := item_color.darkened(0.6 if selected else 0.75)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 12)


## One procedurally-drawn icon per item id -- there is no art for a throwable kunai or a paper tag,
## and the gourds' existing world-pickup art (health_gourd.gd) is a looping animated sprite set, not
## a single still suited to a tiny HUD swatch, so every slot uses the same simple-shape language.
func _draw_icon(c: Control, center: Vector2, item_id: String, color: Color) -> void:
	var r := SLOT_SIZE * 0.5
	match item_id:
		"kunai":
			c.draw_line(center + Vector2(-r * 0.7, r * 0.7), center + Vector2(r * 0.7, -r * 0.7), color, 4.0)
			c.draw_circle(center + Vector2(-r * 0.7, r * 0.7), 3.0, color)
		"paper_tag":
			var half := r * 0.6
			var pts := PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)])
			c.draw_colored_polygon(pts, color)
		_:  # gourds: a simple teardrop
			c.draw_circle(center + Vector2(0, r * 0.15), r * 0.55, color)
			c.draw_circle(center + Vector2(0, -r * 0.35), r * 0.3, color)


func _draw_diamond() -> void:
	if _player == null:
		return
	var items := _player.held_items
	var c := _diamond
	for i in 4:
		var slot_center := DIAMOND_CENTER + DIR_OFFSETS[i] * SLOT_REACH
		var item_id: String = items.order[i]
		var has_any := items.count(item_id) > 0 or item_id == HeldItems.SLOT_UP  # kunai ammo can hit 0 too; just a dimming cue
		var bg := Color(0.05, 0.05, 0.05, 0.8)
		c.draw_circle(slot_center, SLOT_SIZE * 0.5 + 3.0, Color(items.color(item_id), 0.5 if items.count(item_id) > 0 else 0.15))
		c.draw_circle(slot_center, SLOT_SIZE * 0.5, bg)
		_draw_icon(c, slot_center, item_id, items.color(item_id) if items.count(item_id) > 0 else Color(0.5, 0.5, 0.5, 0.5))
		var txt := "x%d" % items.count(item_id)
		var fsize := 13
		var sz := c.get_theme_default_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var badge_pos := slot_center + Vector2(0, SLOT_SIZE * 0.5 + 2.0)
		c.draw_string(c.get_theme_default_font(), badge_pos - Vector2(sz.x * 0.5, -sz.y * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color.WHITE if items.count(item_id) > 0 else COLOR_EMPTY_COUNT)
	c.draw_circle(DIAMOND_CENTER, 4.0, Color(1.0, 0.85, 0.2, 0.9))  # centre dot, matches the owner's reference image
