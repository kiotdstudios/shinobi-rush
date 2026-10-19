class_name PlayerController
extends CharacterBody2D
## Top-down (three-quarter view) movement: walk / sprint with acceleration and friction.
## Origin = feet. Dodge (Space) and jump (F) are one-shot actions that lock out movement input for
## the authored length of their animation. Combat etc. remain reserved with no behavior yet.

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
## Dodge is a quick burst along the facing direction, decaying by `friction` like normal movement.
@export var dodge_speed: float = WorldScale.SPRINT_SPEED * 1.6
## Used only when the active sprite set has no "dodge"/"jump" animation to time against (placeholder visual).
@export var dodge_fallback_duration: float = 0.5
@export var jump_fallback_duration: float = 0.6

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN  ## last movement vector, normalized
var facing8: Vector2 = Vector2.DOWN  ## facing snapped to 8 directions
var camera_baseline: float = WorldScale.CAMERA_BASE_ZOOM  ## zoom of the active CameraPreset for the current figure
var _action_timer: float = 0.0  ## seconds left in the current dodge/jump; input is locked out until it hits 0

@onready var visual: PlayerVisual = $PlayerVisual
@onready var camera: Camera2D = $Camera2D


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
	if state == State.DODGE or state == State.JUMP:
		_action_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		visual.play_action("dodge" if state == State.DODGE else "jump", facing8)  # no-op on the placeholder visual (no dodge/jump frames); it just keeps its last pose
		if _action_timer <= 0.0:
			state = State.IDLE
			state_changed.emit(state)
		return
	if Input.is_action_just_pressed("dodge"):
		_start_action(State.DODGE, "dodge", dodge_fallback_duration)
		velocity = facing8 * dodge_speed
		return
	if Input.is_action_just_pressed("jump"):
		_start_action(State.JUMP, "jump", jump_fallback_duration)
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	var target_speed := sprint_speed if sprinting else walk_speed
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * target_speed, acceleration * delta)
		facing = input.normalized()
		facing8 = _snap8(facing)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	var new_state := State.IDLE
	if input != Vector2.ZERO:
		new_state = State.SPRINT if sprinting else State.MOVE
	if new_state != state:
		state = new_state
		state_changed.emit(state)
	visual.set_pose(facing8, state == State.SPRINT, state != State.IDLE)


## Begin a one-shot dodge/jump: locks out movement input for the authored animation length (or
## `fallback_duration` on the placeholder visual, which has no timing to read), then returns to IDLE.
func _start_action(s: State, aid: String, fallback_duration: float) -> void:
	state = s
	_action_timer = visual.action_duration(aid, fallback_duration)
	state_changed.emit(state)
	visual.play_action(aid, facing8)


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
