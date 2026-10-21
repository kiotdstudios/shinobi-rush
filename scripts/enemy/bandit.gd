class_name Bandit
extends CharacterBody2D
## Basic Bandit: the first combat-capable enemy, for validating player timing/dodging/combos.
## Milestone A scope only (see combat order): idle, detect, approach to combat range, take damage,
## hit-react, die. Attacking/blocking/parry-reacting/guard-break are Milestone B additions (the order
## explicitly scopes "enemy attack telegraphs" to Milestone B) -- this bandit does not yet hit back.
##
## BanditVisual explicitly binds Codex's red-scarf idle/run/sprint art. Dedicated combat/death
## clips remain future art; hurt freezes/flashes the current pose, death retains its fallback.

enum State { IDLE, APPROACH, HIT_REACT, DEAD }

const SKIN := Color("#8a4a3a")
const CLOTH := Color("#4a3a2a")
const HIT_FLASH := Color(1.0, 0.25, 0.2, 0.9)

@export var max_hp: float = 60.0
@export var detect_radius: float = 420.0
@export var combat_distance: float = 130.0  ## approach stops at roughly this range from the player
@export var move_speed: float = 160.0
@export var hit_react_duration: float = 0.22
@export var hit_flash_duration: float = 0.12

var state: State = State.IDLE
var hp: float = max_hp
var facing8: Vector2 = Vector2.DOWN
var _hit_react_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _player: Node2D = null

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	var shape := RectangleShape2D.new()
	shape.size = WorldScale.FOOTPRINT
	var col := $CollisionShape2D as CollisionShape2D
	col.shape = shape
	col.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer - delta, 0.0)
		visual.queue_redraw()
		return  # local hitstop only: this entity's movement pauses, global timers/input elsewhere are untouched

	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)

	if state == State.DEAD:
		return

	if state == State.HIT_REACT:
		_hit_react_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 4.0 * delta)
		move_and_slide()
		if _hit_react_timer <= 0.0:
			state = State.APPROACH if _player != null else State.IDLE
		visual.queue_redraw()
		return

	_find_player()
	if _player == null:
		velocity = Vector2.ZERO
		state = State.IDLE
		visual.queue_redraw()
		return

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if state == State.IDLE and dist <= detect_radius:
		state = State.APPROACH

	if state == State.APPROACH:
		if dist > combat_distance:
			var dir := to_player.normalized()
			velocity = dir * move_speed
			facing8 = WorldScale.snap8(dir)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 4.0 * delta)
			facing8 = WorldScale.snap8(to_player.normalized())
	move_and_slide()
	visual.queue_redraw()


## Called by the player's attack hit-check. `knockback_dir` should already be normalized.
func take_damage(amount: float, knockback_dir: Vector2, knockback_speed: float, hitstop_ms: float) -> void:
	if state == State.DEAD:
		return
	hp = maxf(hp - amount, 0.0)
	_hit_flash_timer = hit_flash_duration
	_hitstop_timer = maxf(_hitstop_timer, hitstop_ms / 1000.0)
	if hp <= 0.0:
		state = State.DEAD
		velocity = Vector2.ZERO
		visual.queue_redraw()
		return
	state = State.HIT_REACT
	_hit_react_timer = hit_react_duration
	velocity = knockback_dir * knockback_speed


func is_alive() -> bool:
	return state != State.DEAD


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var players := get_tree().get_nodes_in_group("player")
	_player = players[0] if players.size() > 0 else null


func get_state_name() -> String:
	return State.keys()[state]
