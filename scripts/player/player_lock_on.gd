class_name PlayerLockOn
extends Node2D
## Target selection (R3 / L) plus the lock-on animation. Does not steer movement, camera, combat or attack hitboxes.
##
## The reticle is drawn in code (no bitmap art), in world space, over the target:
##   ACQUIRE  brackets spin and slam in from far out with a back-ease, ground ring shrinks onto the feet, white snap flash
##   LOCKED   brackets breathe, a dashed ring turns, the ground ring pulses outward, a red chevron bobs over the head
##   RELEASE  brackets burst outward and fade (also plays when the target dies or leaves range)
const RANGE := 650.0
const ACQUIRE_T := 0.32
const RELEASE_T := 0.22
const R0 := 46.0
const GOLD := Color("ffd87a")
const RED := Color("ff4a3d")
const SHADOW := Color(0, 0, 0, 0.55)

enum Phase { NONE, ACQUIRE, LOCKED, RELEASE }

var target: Node2D
var phase := Phase.NONE
var phase_time := 0.0
var _shown: Node2D
var _clock := 0.0
var _anchor := Vector2.ZERO  ## world position of the target's feet (kept after it dies so the release still plays)


func _ready() -> void:
	top_level = true
	z_index = 40
	z_as_relative = false
	global_position = Vector2.ZERO
	if not InputMap.has_action("lock_on"):
		InputMap.add_action("lock_on")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_L
		InputMap.action_add_event("lock_on", key)
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_STICK  # R3
		InputMap.action_add_event("lock_on", button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


## Where the player is (the node is top_level, so its own position is not the player's).
func _origin() -> Vector2:
	var p := get_parent() as Node2D
	return p.global_position if p != null else global_position


func toggle() -> void:
	if valid_target():
		target = null
		return
	target = null
	var nearest := RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		var distance: float = _origin().distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy


func valid_target() -> bool:
	return is_instance_valid(target) and target.has_method("is_alive") and target.is_alive() and _origin().distance_to(target.global_position) <= RANGE


## Unit vector from the player to the locked target, or ZERO when there is no valid lock.
func aim_direction() -> Vector2:
	if not valid_target():
		return Vector2.ZERO
	var d: Vector2 = target.global_position - _origin()
	return d.normalized() if d.length_squared() > 1.0 else Vector2.ZERO


func is_targeted(enemy: Node2D) -> bool:
	return valid_target() and target == enemy


func _process(delta: float) -> void:
	_clock += delta
	advance(delta)
	queue_redraw()


## Steps the lock-on animation state (also called directly by tests).
func advance(delta: float) -> void:
	if valid_target():
		_anchor = target.global_position
		if _shown != target or phase == Phase.RELEASE or phase == Phase.NONE:
			_shown = target
			phase = Phase.ACQUIRE
			phase_time = 0.0
		phase_time += delta
		if phase == Phase.ACQUIRE and phase_time >= ACQUIRE_T:
			phase = Phase.LOCKED
	else:
		target = null
		if phase == Phase.ACQUIRE or phase == Phase.LOCKED:
			phase = Phase.RELEASE
			phase_time = 0.0
		elif phase == Phase.RELEASE:
			phase_time += delta
			if phase_time >= RELEASE_T:
				phase = Phase.NONE
				_shown = null


static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var t := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * t * t * t + c1 * t * t


func _draw() -> void:
	if phase == Phase.NONE:
		return
	var radius := R0
	var alpha := 1.0
	var spin := 0.0
	var ground_scale := 1.0
	match phase:
		Phase.ACQUIRE:
			var e := ease_out_back(phase_time / ACQUIRE_T)
			radius = lerpf(130.0, R0, e)
			spin = (1.0 - e) * PI * 0.75
			ground_scale = lerpf(2.4, 1.0, e)
			alpha = clampf(phase_time / 0.1, 0.0, 1.0)
		Phase.LOCKED:
			radius = R0 + sin(_clock * 5.0) * 2.5
		Phase.RELEASE:
			var k := clampf(phase_time / RELEASE_T, 0.0, 1.0)
			radius = R0 + k * 60.0
			spin = k * 0.6
			ground_scale = 1.0 + k * 0.8
			alpha = 1.0 - k
	var feet := (_anchor + Vector2(0, 4)).round()
	var c := (_anchor + Vector2(0, -60)).round()
	# Ground ring (isometric ellipse) in the danger colour, plus an outward pulse while locked.
	_ellipse(feet, 34.0 * ground_scale, 17.0 * ground_scale, RED, alpha * 0.9, 2.0)
	if phase == Phase.LOCKED:
		var pulse := fmod(_clock, 1.1) / 1.1
		_ellipse(feet, 34.0 * (1.0 + pulse * 0.7), 17.0 * (1.0 + pulse * 0.7), RED, (1.0 - pulse) * 0.6, 1.5)
	# Four corner brackets, each with a dark underlay so they read on any floor.
	for i in 4:
		var a := PI * 0.5 * i + PI * 0.25 + spin
		draw_arc(c, radius, a - 0.3, a + 0.3, 8, Color(SHADOW, SHADOW.a * alpha), 6.0)
		draw_arc(c, radius, a - 0.3, a + 0.3, 8, Color(GOLD, alpha), 3.0)
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * (radius - 7.0), c + dir * (radius + 7.0), Color(GOLD, alpha), 2.0)
	if phase == Phase.LOCKED or phase == Phase.ACQUIRE:
		# Dashed ring turning slowly outside the brackets.
		for i in 12:
			var a := TAU * i / 12.0 + _clock * 0.9
			draw_arc(c, radius + 12.0, a, a + 0.28, 4, Color(GOLD, alpha * 0.55), 1.5)
		# White snap flash the instant the brackets land.
		var f := phase_time - (ACQUIRE_T - 0.04)
		if f > 0.0 and f < 0.3:
			var k := f / 0.3
			draw_arc(c, R0 + k * 70.0, 0.0, TAU, 32, Color(1, 1, 1, (1.0 - k) * 0.85), 3.0 * (1.0 - k) + 1.0)
		# Red chevron bobbing over the head.
		var bob := sin(_clock * 6.0) * 3.0
		var tip := c + Vector2(0, -radius - 8.0 + bob).round()
		var tri := PackedVector2Array([tip + Vector2(0, 8), tip + Vector2(-8, -4), tip + Vector2(8, -4)])
		draw_colored_polygon(tri, Color(RED, alpha))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(SHADOW, alpha * 0.8), 1.5)


func _ellipse(center: Vector2, rx: float, ry: float, col: Color, alpha: float, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, Color(col, alpha), width)
