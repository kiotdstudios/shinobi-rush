class_name DockTab
extends RefCounted
## Binder-divider styling for the screen-top debug buttons (Lab, Bandit vision, Sense vision).
## A tab rests tucked above the top edge with only its coloured lip showing, slides part-way down while the mouse is
## over it so you can read the label, and pops fully down while its feature is ON. Clicking it again pops it back up.
## The Button node keeps its text, toggle behaviour and x/size; only its y (and look) change, so existing callers/tests work.
const REST_Y := -19.0  ## 7 px coloured lip only (label hidden)
const HOVER_Y := -6.0  ## label readable
const OUT_Y := 0.0  ## selected: fully down
const SLIDE_TIME := 0.16


static func style(b: Button, color: Color) -> void:
	var bg := color.darkened(0.62)
	b.add_theme_stylebox_override("normal", _box(bg, color))
	b.set_meta("dock_color", color)
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), color))
	b.add_theme_stylebox_override("pressed", _box(color, color.lightened(0.35)))
	b.add_theme_stylebox_override("hover_pressed", _box(color.lightened(0.08), color.lightened(0.35)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#0a0a0a"))
	b.add_theme_color_override("font_hover_pressed_color", Color("#0a0a0a"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("dock_hover", false)
	b.set_meta("dock_active", false)
	b.mouse_entered.connect(func(): _hover(b, true))
	b.mouse_exited.connect(func(): _hover(b, false))
	b.position.y = REST_Y


static func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_bottom = 4
	s.corner_radius_bottom_left = 9
	s.corner_radius_bottom_right = 9
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 4
	return s


## Call whenever the feature behind the tab switches (pops the tab down/up).
static func set_active(b: Button, active: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
	b.set_meta("dock_active", active)
	var color: Color = b.get_meta("dock_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(color, color.lightened(0.35)) if active else _box(color.darkened(0.62), color))
	_slide(b)


static func _hover(b: Button, over: bool) -> void:
	if is_instance_valid(b):
		b.set_meta("dock_hover", over)
		_slide(b)


static func target_y(b: Button) -> float:
	if bool(b.get_meta("dock_active", false)):
		return OUT_Y
	return HOVER_Y if bool(b.get_meta("dock_hover", false)) else REST_Y


static func _slide(b: Button) -> void:
	var y := target_y(b)
	if not b.is_inside_tree():
		b.position.y = y
		return
	if b.has_meta("dock_tween"):
		var old: Variant = b.get_meta("dock_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := b.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "position:y", y, SLIDE_TIME)
	b.set_meta("dock_tween", tw)
