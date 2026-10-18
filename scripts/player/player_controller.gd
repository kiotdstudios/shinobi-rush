class_name PlayerController
extends CharacterBody2D
## Top-down (three-quarter view) movement: walk / sprint with acceleration and friction.
## Origin = feet. Combat, jump, dodge etc. are reserved actions with no behavior yet.

signal state_changed(new_state: State)

enum State { IDLE, MOVE, SPRINT }

## Handoff prototype values (px/s, px/s^2).
@export var walk_speed: float = 175.0
@export var sprint_speed: float = 270.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export var camera_smoothing_speed: float = 8.0

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN  ## last movement vector, normalized
var facing8: Vector2 = Vector2.DOWN  ## facing snapped to 8 directions

@onready var visual: PlayerVisual = $PlayerVisual
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = camera_smoothing_speed
	var arena := get_parent()
	if arena != null and arena.has_method("get_bounds"):
		var b: Rect2 = arena.get_bounds()
		camera.limit_left = int(b.position.x)
		camera.limit_top = int(b.position.y)
		camera.limit_right = int(b.end.x)
		camera.limit_bottom = int(b.end.y)
	visual.set_pose(facing8, false, false)


func _physics_process(delta: float) -> void:
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


func reset_camera() -> void:
	camera.reset_smoothing()


func get_state_name() -> String:
	return State.keys()[state]


## Snap a direction to one of 8 unit-ish headings (diagonals normalized).
static func _snap8(dir: Vector2) -> Vector2:
	var idx := int(roundf(dir.angle() / (PI / 4.0)))
	return Vector2.from_angle(idx * (PI / 4.0)).snapped(Vector2(0.01, 0.01))
