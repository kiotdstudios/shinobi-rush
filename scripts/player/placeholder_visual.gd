class_name PlaceholderVisual
extends Node2D
## PLACEHOLDER procedural silhouette. Replaceable by Codex's AnimatedSprite2D later.
## Origin = feet / ground contact. Redraws only when the pose changes.

const SKIN := Color("#e0b48a")
const CLOTH := Color("#2f3a56")
const LIMB := Color("#232c42")
const SHADOW := Color(0, 0, 0, 0.35)
const INDICATOR := Color("#ffd23f")

var _dir: Vector2 = Vector2.DOWN
var _sprinting: bool = false
var _moving: bool = false
var _drawn_zoom: float = -1.0


func _camera_zoom() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	return cam.zoom.x if cam != null else 1.0


func _process(_d: float) -> void:
	if not is_equal_approx(_camera_zoom(), _drawn_zoom):
		queue_redraw()  # caption size depends on the camera zoom


func set_pose(dir8: Vector2, sprinting: bool, moving: bool) -> void:
	if dir8 == _dir and sprinting == _sprinting and moving == _moving:
		return
	_dir = dir8
	_sprinting = sprinting
	_moving = moving
	queue_redraw()


func _draw() -> void:
	# Procedural figure is authored at its native size and scaled to the ~108 px standard (WorldScale).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * WorldScale.FIGURE_SCALE)
	# Elliptical ground shadow (fixed under the feet).
	var shadow := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		shadow.append(Vector2(cos(a) * 15.0, sin(a) * 6.0))
	draw_colored_polygon(shadow, SHADOW)
	# Facing indicator on the ground, projected 2:1.
	var f := Vector2(_dir.x * 22.0, _dir.y * 11.0)
	var side := Vector2(-_dir.y * 5.0, _dir.x * 2.5)
	draw_colored_polygon(PackedVector2Array([f + _dir * Vector2(6, 3), f + side, f - side]), INDICATOR)
	# Pose: sprint leans the torso forward and sweeps both arms back.
	var lean := Vector2(_dir.x * 9.0, 4.0 + _dir.y * 3.0) if _sprinting else Vector2.ZERO
	var hip := Vector2(0, -20)
	var neck := hip + Vector2(0, -22) + lean
	var head := neck + Vector2(0, -8) + lean * 0.3
	# Legs (stride when moving).
	var stride := 0.0
	if _moving:
		stride = 8.0 if _sprinting else 4.0
	draw_line(hip, Vector2(-5 - stride, 0), LIMB, 4.0)
	draw_line(hip, Vector2(5 + stride, 0), LIMB, 4.0)
	# Torso.
	draw_line(hip, neck, CLOTH, 9.0)
	# Arms.
	var shoulder := neck + Vector2(0, 3)
	if _sprinting:
		var back := Vector2(-_dir.x * 14.0, -_dir.y * 4.0 - 4.0)
		draw_line(shoulder + Vector2(-4, 0), shoulder + back + Vector2(-4, 6), LIMB, 3.0)
		draw_line(shoulder + Vector2(4, 0), shoulder + back + Vector2(4, 6), LIMB, 3.0)
	else:
		draw_line(shoulder + Vector2(-5, 0), shoulder + Vector2(-8, 14), LIMB, 3.0)
		draw_line(shoulder + Vector2(5, 0), shoulder + Vector2(8, 14), LIMB, 3.0)
	# Head with a small facing mark.
	draw_circle(head, 7.0, SKIN)
	draw_circle(head + Vector2(_dir.x * 4.0, _dir.y * 2.0), 2.0, INDICATOR)
	# Caption is drawn under FIGURE_SCALE, so account for it to stay >= 8 screen px.
	_drawn_zoom = _camera_zoom()
	var csize := WorldScale.caption_font_size(8, _drawn_zoom, WorldScale.FIGURE_SCALE)
	var cw := 60.0 * csize / 8.0
	draw_string(ThemeDB.fallback_font, Vector2(-cw * 0.5, head.y - 14.0), "PLACEHOLDER", HORIZONTAL_ALIGNMENT_CENTER, cw, csize, Color(1, 1, 1, 0.7))
