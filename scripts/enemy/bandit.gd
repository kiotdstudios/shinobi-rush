class_name Bandit
extends CharacterBody2D
## Basic Bandit: the first combat-capable enemy, for validating player timing/dodging/combos.
## Milestone A scope only (see combat order): idle, detect, approach to combat range, take damage,
## hit-react, die. Attacking/blocking/parry-reacting/guard-break are Milestone B additions (the order
## explicitly scopes "enemy attack telegraphs" to Milestone B) -- this bandit does not yet hit back.
##
## BanditVisual explicitly binds Codex's red-scarf idle/run/sprint art. Dedicated combat/death
## clips remain future art; hurt freezes/flashes the current pose, death retains its fallback.

enum State { IDLE, APPROACH, HIT_REACT, DEAD, EVADE }

const SKIN := Color("#8a4a3a")
const CLOTH := Color("#4a3a2a")
const HIT_FLASH := Color(1.0, 0.25, 0.2, 0.9)

@export var max_hp: float = 60.0
@export var detect_radius: float = 420.0
@export var combat_distance: float = 130.0  ## approach stops at roughly this range from the player
@export var move_speed: float = 320.0
@export var chase_speed: float = 470.0
@export var evade_speed: float = 640.0
@export var evade_duration: float = 0.20
@export var evade_cooldown: float = 1.25
var is_sprinting := false
var evade_count := 0
var _evade_timer := 0.0
var _evade_cooldown := 0.0
var _evade_side := 1.0
var _holding_distance := false
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
	_evade_cooldown = maxf(_evade_cooldown - delta, 0.0)

	if state == State.DEAD:
		return
	if state == State.EVADE:
		var remaining := minf(delta, _evade_timer)
		var burst_velocity := velocity
		velocity *= remaining / maxf(delta, 0.00001)
		move_and_slide()
		velocity = burst_velocity
		_evade_timer -= delta
		if _evade_timer <= 0.0 or get_slide_collision_count() > 0:
			state = State.APPROACH
			velocity = Vector2.ZERO
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
		if _should_evade(to_player) and _begin_evade(to_player):
			_evade_timer -= delta
			move_and_slide()
			return
		if dist > combat_distance + 24.0:
			_holding_distance = false
		elif dist <= combat_distance:
			_holding_distance = true
		if not _holding_distance:
			var dir := to_player.normalized()
			if dist > 250.0:
				is_sprinting = true
			elif dist < 185.0:
				is_sprinting = false
			velocity = dir * (chase_speed if is_sprinting else move_speed)
			facing8 = WorldScale.snap8(dir)
		else:
			is_sprinting = false
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 4.0 * delta)
			facing8 = WorldScale.snap8(to_player.normalized())
	move_and_slide()
	visual.queue_redraw()


func _should_evade(to_player: Vector2) -> bool:
	if _evade_cooldown > 0.0 or to_player.length() > 260.0 or to_player.length_squared() < 1.0:
		return false
	var lock := _player.get_node_or_null("LockOn")
	if lock != null and lock.is_targeted(self):
		return true
	var body := _player as CharacterBody2D
	return body != null and body.velocity.dot(-to_player.normalized()) > 100.0


func _begin_evade(to_player: Vector2) -> bool:
	var away := -to_player.normalized()
	var tangent := Vector2(-away.y, away.x)
	for side: float in [_evade_side, -_evade_side]:
		var direction := (tangent * side + away * 0.35).normalized()
		# Test the complete burst, including the existing body collider. Never teleport through walls.
		if test_move(global_transform, direction * evade_speed * evade_duration):
			continue
		velocity = direction * evade_speed
		facing8 = WorldScale.snap8(direction)
		state = State.EVADE
		is_sprinting = true
		_holding_distance = false
		_evade_timer = evade_duration
		_evade_cooldown = evade_cooldown
		_evade_side = -side
		evade_count += 1
		return true
	return false


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
