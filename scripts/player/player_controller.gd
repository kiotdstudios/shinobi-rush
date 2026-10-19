class_name PlayerController
extends CharacterBody2D
## Top-down (three-quarter view) movement: walk / sprint with acceleration and friction.
## Origin = feet. Dodge (Space) and jump (F) are one-shot actions that run alongside movement:
## momentum is never zeroed on entry or exit, so a run carries straight through into the action and
## straight back out of it. Combat etc. remain reserved with no behavior yet.

signal state_changed(new_state: State)
## The camera baseline zoom was recomputed (preset switched, or the figure height changed with the sprite set).
signal camera_baseline_changed(zoom: float)

enum State { IDLE, MOVE, SPRINT, DODGE, JUMP }

## Provisional prototype values (px/s, px/s^2), handoff values scaled by WorldScale.SCALE.
## Not balance: Aki/Orcha re-tune.
@export var walk_speed: float = WorldScale.WALK_SPEED
@export var sprint_speed: float = WorldScale.SPRINT_SPEED
@export var acceleration: float = WorldScale.ACCELERATION
@export var friction: float = WorldScale.FRICTION
@export var camera_smoothing_speed: float = 8.0
## Dodge is a quick burst along the dodge direction; velocity then eases (at `dodge_recovery_accel`,
## not the generic ground `friction`) toward whatever speed current input calls for, or to a stop if none.
@export var dodge_speed: float = WorldScale.SPRINT_SPEED * 1.6
@export var dodge_recovery_accel: float = WorldScale.ACCELERATION * 1.5
## Air control: fraction of normal ground `acceleration` used to steer velocity while airborne.
## Momentum itself is never reset on jump entry/exit; this only lets input bend an already-moving arc.
@export var air_control_mult: float = 0.6
## Visual-only peak height (px) of the jump arc. Purely cosmetic: applied to PlayerVisual's local
## position, never to this body's position, so collision and the arena's Y-sort (which keys off this
## node's own global_position.y) are completely unaffected by being airborne.
@export var jump_visual_height: float = 34.0
## Input buffer window (seconds) for dodge/jump: a press up to this long before the action becomes
## legal (i.e. while the previous dodge/jump is still finishing) is remembered and fires the instant
## it's allowed, instead of being dropped.
@export var input_buffer_window: float = 0.12
## Used only when the active sprite set has no "dodge"/"jump" animation to time against (placeholder visual).
@export var dodge_fallback_duration: float = 0.5
@export var jump_fallback_duration: float = 0.6
## Seconds between dirt-puff bursts while running on the ground (SPRINT uses a shorter interval,
## see `_update_footsteps()`), roughly matched to footstep cadence.
@export var footstep_interval_walk: float = 0.28
@export var footstep_interval_sprint: float = 0.18

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN  ## last movement vector, normalized
var facing8: Vector2 = Vector2.DOWN  ## facing snapped to 8 directions
var camera_baseline: float = WorldScale.CAMERA_BASE_ZOOM  ## zoom of the active CameraPreset for the current figure
var _action_timer: float = 0.0  ## seconds left in the current dodge/jump; 0 when not acting
var _action_duration: float = 0.0  ## total authored length of the current/last action, for progress math
var _dodge_buffer: float = 0.0  ## seconds left that a buffered dodge press is still eligible to fire
var _jump_buffer: float = 0.0  ## seconds left that a buffered jump press is still eligible to fire
var _footstep_timer: float = 0.0  ## seconds left until the next running dirt-puff burst

@onready var visual: PlayerVisual = $PlayerVisual
@onready var camera: Camera2D = $Camera2D
@onready var dust: DustPuff = $DustPuff


func _ready() -> void:
	add_to_group("player")
	# Collider comes from the shared footprint constant (the scene values mirror it).
	var feet := $CollisionShape2D as CollisionShape2D
	(feet.shape as RectangleShape2D).size = WorldScale.FOOTPRINT
	feet.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	camera_baseline = baseline_zoom()  # single source of truth: the active CameraPreset (player.tscn has no literal)
	camera.zoom = Vector2.ONE * camera_baseline
	visual.sprite_set_changed.connect(func(_s: SpriteSet) -> void: refresh_camera_baseline())
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = camera_smoothing_speed
	var arena := get_parent()
	if arena != null and arena.has_method("get_bounds"):
		var b: Rect2 = arena.get_bounds()
		camera.limit_left = int(b.position.x)
		camera.limit_top = int(b.position.y - WorldScale.CAMERA_HEADROOM)  # head room: a figure at the top wall is not clipped
		camera.limit_right = int(b.end.x)
		camera.limit_bottom = int(b.end.y + WorldScale.CAMERA_FOOTROOM)  # foot room: feet and shadow at the bottom wall are not cut off
	visual.set_pose(facing8, false, false)


func _physics_process(delta: float) -> void:
	var prev_state := state
	_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer = input_buffer_window
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = input_buffer_window

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	var target_speed := sprint_speed if sprinting else walk_speed

	var still_acting := false
	if state == State.DODGE or state == State.JUMP:
		_action_timer -= delta
		if state == State.JUMP:
			# Momentum is never zeroed: with no input the arc simply continues; with input it bends
			# (at a reduced, "air control" rate) toward the new heading instead of snapping to it.
			if input != Vector2.ZERO:
				velocity = velocity.move_toward(input * target_speed, acceleration * air_control_mult * delta)
		else:  # DODGE
			# Dedicated curve: the initial burst (set on trigger) eases toward whatever speed current
			# input calls for (0 if none) at `dodge_recovery_accel`, not the generic ground `friction`.
			velocity = velocity.move_toward(input * target_speed, dodge_recovery_accel * delta)
		if input != Vector2.ZERO:
			facing = input.normalized()
			facing8 = _snap8(facing)
		still_acting = _action_timer > 0.0

	if still_acting:
		move_and_slide()
		visual.play_action("dodge" if state == State.DODGE else "jump", facing8)
		_update_jump_lift()
		_footstep_timer = 0.0
		if state != prev_state:
			state_changed.emit(state)
		return

	# Not mid-action this frame (either never was, or the action just finished above with velocity
	# already correct) -> a buffered dodge/jump takes priority over plain locomotion, then plain
	# locomotion, then idle decay. Exactly one of the three branches below runs.
	if _dodge_buffer > 0.0 or _jump_buffer > 0.0:
		if _dodge_buffer >= _jump_buffer:
			_dodge_buffer = 0.0
			_begin_dodge(input)
		else:
			_jump_buffer = 0.0
			_begin_jump()
	elif input != Vector2.ZERO:
		velocity = velocity.move_toward(input * target_speed, acceleration * delta)
		facing = input.normalized()
		facing8 = _snap8(facing)
		state = State.SPRINT if sprinting else State.MOVE
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		state = State.IDLE
	move_and_slide()
	_update_jump_lift()
	if state == State.DODGE or state == State.JUMP:
		visual.play_action("dodge" if state == State.DODGE else "jump", facing8)
	else:
		visual.set_pose(facing8, state == State.SPRINT, state != State.IDLE)
	if prev_state == State.JUMP and state != State.JUMP:
		dust.burst(global_position, 1.2)  # landing kicks up a bit less dirt than the takeoff did
	_update_footsteps(delta)
	if state != prev_state:
		state_changed.emit(state)


## Begin a dodge: direction comes from current input if any is held, else the last facing (order:
## "directional dodging based on current input or last facing direction"). Velocity jumps straight to
## the burst speed in that direction -- there is no separate "stop, then dodge" step.
func _begin_dodge(input: Vector2) -> void:
	var dir := input.normalized() if input != Vector2.ZERO else facing8
	facing8 = _snap8(dir)
	if input != Vector2.ZERO:
		facing = input.normalized()
	state = State.DODGE
	_action_duration = visual.action_duration("dodge", dodge_fallback_duration)
	_action_timer = _action_duration
	velocity = facing8 * dodge_speed
	visual.play_action("dodge", facing8)


## Begin a jump. `velocity` is intentionally left untouched: whatever horizontal momentum the player
## already had carries straight into the air (order: "do not reset movement velocity when entering or
## exiting the jump state").
func _begin_jump() -> void:
	state = State.JUMP
	_action_duration = visual.action_duration("jump", jump_fallback_duration)
	_action_timer = _action_duration
	visual.play_action("jump", facing8)
	dust.burst(global_position, 1.5)


## Periodic dirt-puff bursts while running on the ground (MOVE/SPRINT only). Timer resets to 0 by the
## still-acting path above whenever a dodge/jump is in progress, so running resumes with an immediate
## puff on the first step out of an action rather than waiting out a stale interval.
func _update_footsteps(delta: float) -> void:
	if state != State.MOVE and state != State.SPRINT:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		dust.burst(global_position, 0.8 if state == State.SPRINT else 0.6)
		_footstep_timer = footstep_interval_sprint if state == State.SPRINT else footstep_interval_walk


## Visual-only elevation arc for the current jump (0 outside JUMP). Applied to PlayerVisual's local
## position -- never to this body's position -- so the logical ground position used for collision and
## the arena's Y-sort (keyed off this node's own global_position.y, see arena_sort.gd) never moves.
func _update_jump_lift() -> void:
	if state != State.JUMP or _action_duration <= 0.0:
		visual.position.y = 0.0
		return
	var progress := clampf(1.0 - (_action_timer / _action_duration), 0.0, 1.0)
	visual.position.y = -jump_visual_height * sin(progress * PI)


## Height of the standing figure in world px: the loaded sprite set's `body_height_px`, else the placeholder.
func figure_height_px() -> float:
	return CameraPreset.figure_height_px(visual.sprite_set)


## Baseline zoom of the active preset for the current figure.
func baseline_zoom() -> float:
	return CameraPreset.zoom_for(CameraPreset.active(), figure_height_px())


## Recompute the baseline (preset switched, or the sprite set changed the figure height). The camera follows
## only while it sits on the old baseline, so a lab zoom step (1x..4x) is never overwritten.
func refresh_camera_baseline() -> void:
	var old := camera_baseline
	camera_baseline = baseline_zoom()
	if is_equal_approx(camera.zoom.x, old):
		camera.zoom = Vector2.ONE * camera_baseline
	camera_baseline_changed.emit(camera_baseline)


func reset_camera() -> void:
	camera.reset_smoothing()


func get_state_name() -> String:
	return State.keys()[state]


## Snap a direction to one of 8 unit-ish headings (diagonals normalized).
static func _snap8(dir: Vector2) -> Vector2:
	var idx := int(roundf(dir.angle() / (PI / 4.0)))
	return Vector2.from_angle(idx * (PI / 4.0)).snapped(Vector2(0.01, 0.01))
