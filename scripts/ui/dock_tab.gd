class_name DockTab
extends RefCounted
## Binder-divider styling for the bottom-edge "game dev" tabs (Lab, Bandit vision, Sense vision, Player, Controls, Diagnostics).
## A tab STICKS OUT of the bottom edge while its feature is OFF, and tucks away (only a 3 px sliver left) while the feature is ON.
## While tucked, hovering the sliver slides it back out so you can click it to switch the feature off (the hotkeys always work too).
## The Button node keeps its text, toggle behaviour and x/size; only its y (and look) change, so existing callers/tests work.
const BASE_H := 720.0  ## project viewport height (canvas_items + keep aspect: always 1280x720 in canvas space)
const TAB_H := 26.0
const REST_Y := BASE_H - TAB_H  ## OFF: sticking out, label readable
const OUT_Y := REST_Y
const HIDDEN_Y := BASE_H - 3.0  ## ON: tucked away below the edge
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
	s.border_width_top = 4
	s.corner_radius_top_left = 9
	s.corner_radius_top_right = 9
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## Call whenever the feature behind the tab switches (ON tucks the tab away, OFF sticks it back out).
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
	if bool(b.get_meta("dock_active", false)) and not bool(b.get_meta("dock_hover", false)):
		return HIDDEN_Y
	return OUT_Y


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
