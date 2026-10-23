class_name PlayerController
extends CharacterBody2D
## Top-down (three-quarter view) movement: walk / sprint with acceleration and friction, plus the
## katana combat state machine (combat order "SHINOBI RUSH — COMBAT SYSTEM V1", Milestone A).
## Origin = feet. Dodge (Space), jump (F) and the light-attack combo (J) are all one-shot/extended
## actions that share this single controller and its one `velocity`: none of them fight each other or
## the base locomotion for ownership. Momentum is never zeroed on entry or exit of any action, so a
## run carries straight through into the action and straight back out of it.
## Block/parry/posture (Milestone B) are not implemented yet.

signal state_changed(new_state: State)
## The camera baseline zoom was recomputed (preset switched, or the figure height changed with the sprite set).
signal camera_baseline_changed(zoom: float)
## An enemy attack connected (Level 1 Bandit order). There is deliberately no player HP/death here:
## the locked RPG/death rules are untouched; this only counts the hit and gives a short readable reaction.
signal hit_taken(damage: float, from_dir: Vector2)
signal health_changed(current: float, maximum: float)
signal chakra_changed(current: float, maximum: float)
## Substitution charges (shown as pips on the HUD). Only the stat exists so far; the Substitution jutsu will spend them.
signal substitution_changed(charges: int, maximum: int)
signal downed  ## health reached 0 (the player is restored to full right after; there is no death screen yet)
## Currency changed (spent, or stolen by an enemy via lose_ryo() -- see Bandit._steal_ryo/is_worth_robbing).
## No player death/HP system exists here (locked RPG rules); this only tracks the stat.
signal ryo_changed(new_amount: int)

enum State { IDLE, MOVE, SPRINT, DODGE, JUMP, LIGHT1, LIGHT2, LIGHT3, DASH_ATTACK, AIR_ATTACK }
## Phase of the current attack (LIGHT1/LIGHT2/LIGHT3/DASH_ATTACK states only). Startup/active/recovery
## lengths come from the matching AttackDef in `_attack_table` (see combat order's frame table).
enum AttackPhase { STARTUP, ACTIVE, RECOVERY }

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
## Body Flicker dodge: the body vanishes, is displaced `flicker_distance` px along the dodge heading in
## one step (stopped by walls), and reappears; no sliding. Invulnerable for the whole `flicker_duration`.
@export var flicker_distance: float = 150.0
@export var flicker_duration: float = 0.30
@export var flicker_vanish_at: float = 0.04  ## seconds after the press that the body disappears (and moves)
@export var flicker_reappear_at: float = 0.16
@export var dodge_recovery_accel: float = WorldScale.ACCELERATION * 1.5
## Air control: fraction of normal ground `acceleration` used to steer velocity while airborne.
## Momentum itself is never reset on jump entry/exit; this only lets input bend an already-moving arc.
@export var air_control_mult: float = 0.6
## Horizontal air-speed cap (px/s) for JUMP / AIR_ATTACK. The jump lasts as long as its art (2.0 s), and
## the air has no ground friction, so without a cap a sprint jump coasted ~1200 px (owner: "jumping
## launches player super far"). Anything faster on entry (sprint, dodge burst) is braked down to this
## at `jump_air_brake` -- smoothly, never snapped. ~0.4 x walk speed => at most ~330 px over a full jump.
@export var jump_air_speed_cap: float = WorldScale.WALK_SPEED * 0.4
## Deceleration (px/s^2) applied to speed above the cap on jump entry (no stacking of dodge/sprint speed).
@export var jump_air_brake: float = WorldScale.ACCELERATION * 1.5
## Gentle air drag (px/s^2) when no direction is held, so a released jump settles instead of gliding.
@export var jump_air_drag: float = WorldScale.ACCELERATION * 0.25
## Visual-only peak height (px) of the jump arc. Purely cosmetic: applied to PlayerVisual's local
## position, never to this body's position, so collision and the arena's Y-sort (which keys off this
## node's own global_position.y) are completely unaffected by being airborne.
@export var jump_visual_height: float = 34.0
## Input buffer window (seconds) for dodge/jump/attack: a press up to this long before the action
## becomes legal (i.e. while the previous action is still finishing) is remembered and fires the
## instant it's allowed, instead of being dropped.
@export var input_buffer_window: float = 0.12
## Used only when the active sprite set has no matching action animation to time against (placeholder visual).
@export var dodge_fallback_duration: float = 0.5
@export var jump_fallback_duration: float = 0.6
## Gameplay duration of a jump (s). The 24-frame jump art (2.0 s at its authored 12 fps) is played
## compressed to this (frame follows jump progress, so no frames are lost and an air attack cannot
## restart it). Owner target 0.7-1.0 s; <= 0 means "use the art's authored duration". A re-cut of the
## art to this length is requested from Codex; this export is the single place to tune it.
@export var jump_duration: float = 0.85
## Seconds between dirt-puff bursts while running on the ground (SPRINT uses a shorter interval,
## see `_update_footsteps()`), roughly matched to footstep cadence.
@export var footstep_interval_walk: float = 1.1  ## roughly every 4th step; +-jitter applied per puff
@export var footstep_interval_sprint: float = 0.72
## Dash attack is available during the last stretch of an active dodge (seconds of `_action_timer`
## remaining counts as "late") -- order section 4: "available during an approved late-dodge ... window".
@export var dash_attack_late_window: float = 0.08
## Dash attack is also available for a short beat after a dodge ends outright -- order section 4:
## "... or post-dodge window". Expires fast enough that it never swallows a deliberate plain light1
## thrown a beat after the dodge has fully resolved.
@export var dash_attack_post_grace: float = 0.15
## Sense stat (owner: "the higher the stat the bigger the circle"): widens the omnidirectional
## proximity-detection radius used while SPRINTing ("naruto running"), see ProximitySense/sense_radius().
## PROVISIONAL PROTOTYPE value, not balance.
@export var intelligence: int = 5
## Currency (owner 2026-10-22: "bandit lvl 1 is looking for players with under 30 ryo to try to steal
## it"). Default is deliberately above that threshold so a fresh player is not an automatic target.
## PROVISIONAL PROTOTYPE value -- no economy/shop/save system exists yet, not balance.
@export var ryo: int = 50

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN  ## last movement vector, normalized
var facing8: Vector2 = Vector2.DOWN  ## facing snapped to 8 directions
var camera_baseline: float = WorldScale.CAMERA_BASE_ZOOM  ## zoom of the active CameraPreset for the current figure
var _action_timer: float = 0.0  ## seconds left in the current dodge/jump; 0 when not acting
var _action_duration: float = 0.0  ## total authored length of the current/last action, for progress math
var _dodge_buffer: float = 0.0  ## seconds left that a buffered dodge press is still eligible to fire
var _jump_buffer: float = 0.0  ## seconds left that a buffered jump press is still eligible to fire
var _footstep_timer: float = 0.0  ## seconds left until the next running dirt-puff burst

## -- Combat (Milestone A) --
var _attack_table: Dictionary = {}  ## built once in _ready() from AttackDef.build_table()
var _attack_phase: AttackPhase = AttackPhase.STARTUP
var _attack_timer: float = 0.0  ## seconds left in the current attack phase
var _attack_def: AttackDef = null  ## tuning for the attack currently in progress (null when none)
var _combo_index: int = 0  ## 0 = no combo in progress; else 1/2/3 = which light hit is active
var _attack_buffer: float = 0.0  ## seconds left that a buffered attack_light press is still eligible
var _hit_targets: Array = []  ## enemies already damaged by the current swing (each swing hits once)
var _dash_grace_timer: float = 0.0  ## seconds left of the post-dodge dash-attack window
var _hitstop_timer: float = 0.0  ## local-only pause (not Engine.time_scale): see _physics_process top
const MAX_HEALTH := 100.0
var max_health: float = MAX_HEALTH
var health: float = MAX_HEALTH
var times_downed: int = 0
const MAX_CHAKRA := 100.0
const MAX_SUBSTITUTIONS := 3
var max_chakra: float = MAX_CHAKRA
var chakra: float = MAX_CHAKRA
var max_substitution_charges: int = MAX_SUBSTITUTIONS
var substitution_charges: int = MAX_SUBSTITUTIONS
var _flicker_hidden: bool = false
var _flicker_moved: bool = false
var flicker_count: int = 0
var hits_taken: int = 0  ## enemy hits that landed on the player (read by tests / web smoke state)
var hit_flash_timer: float = 0.0
var _hit_invuln: float = 0.0  ## brief grace after a hit so one combo cannot chain-stun the player
const HIT_INVULN_TIME := 0.45
const HIT_FLASH_TIME := 0.18
const HIT_TINT := Color(1.0, 0.45, 0.4, 1.0)

## -- Proximity sense ("naruto running" auto-detect) --
var sensed_enemy: Node2D = null  ## nearest enemy inside the sense circle this frame while SPRINTing, else null
var kunai_drawn: bool = false  ## true the instant `sensed_enemy` is non-null (read by tests / web smoke state)

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
	_attack_table = AttackDef.build_table()
	var bar := HealthBar.new()
	bar.name = "HealthBar"
	add_child(bar)
	bar.bind(self)


func _physics_process(delta: float) -> void:
	var prev_state := state
	# Cleared every frame, only re-populated below in the plain-SPRINT locomotion branch: sensing is a
	# fresh, every-frame read, never a sticky flag that survives into dodge/attack/jump/idle frames.
	sensed_enemy = null
	kunai_drawn = false
	_hit_invuln = maxf(_hit_invuln - delta, 0.0)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
		visual.modulate = HIT_TINT if hit_flash_timer > 0.0 else Color.WHITE

	# Presses are captured EVERY physics tick, including hitstop ticks (Milestone A fluidity order:
	# "buffered inputs must survive hitstop"). Before this, a press landing inside the 3-4 tick
	# freeze was silently dropped.
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer = input_buffer_window
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = input_buffer_window
	if Input.is_action_just_pressed("attack_light"):
		_attack_buffer = input_buffer_window

	# Local hitstop: pause this body's own velocity/position integration only -- NOT Engine.time_scale
	# (the order forbids a global freeze). Buffers do not decay while frozen, so a press made just
	# before or during the freeze is still live the instant it ends, and attack/cancel windows resume
	# exactly where they stopped.
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer - delta, 0.0)
		return

	_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_dash_grace_timer = maxf(_dash_grace_timer - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	var target_speed := sprint_speed if sprinting else walk_speed

	if _is_attack_state(state):
		_process_attack_state(delta, input)
		if state != prev_state:
			state_changed.emit(state)
		return

	# Late-dodge dash-attack trigger: pressing attack while still inside a dodge's last stretch cancels
	# the remainder of the dodge straight into a dash attack (order: "available during an approved
	# late-dodge ... window") instead of waiting for the dodge to finish.
	if state == State.DODGE and _attack_buffer > 0.0 and _action_timer <= dash_attack_late_window:
		_attack_buffer = 0.0
		_begin_attack("dash_attack", input)
		move_and_slide()
		if state != prev_state:
			state_changed.emit(state)
		return

	# Aerial attack: an attack press while airborne swings without ending the jump. The jump arc and
	# its timer keep running underneath (AIR_ATTACK), so the player lands on schedule and rolls
	# straight back into locomotion: run -> jump -> aerial attack -> land -> run.
	if state == State.JUMP and _attack_buffer > 0.0:
		_attack_buffer = 0.0
		_begin_attack("air_attack", input)
		move_and_slide()
		_update_jump_lift()
		if state != prev_state:
			state_changed.emit(state)
		return

	var still_acting := false
	if state == State.DODGE or state == State.JUMP:
		_action_timer -= delta
		if state == State.JUMP:
			# Momentum is never zeroed: with no input the arc simply continues; with input it bends
			# (at a reduced, "air control" rate) toward the new heading instead of snapping to it.
			_air_move(input, delta)
		else:  # DODGE
			# Dedicated curve: the initial burst (set on trigger) eases toward whatever speed current
			# input calls for (0 if none) at `dodge_recovery_accel`, not the generic ground `friction`.
			# Body Flicker: no lunge or slide. The displacement is a single step (see _flicker_step).
			velocity = Vector2.ZERO
			_flicker_step()
		if input != Vector2.ZERO:
			facing = input.normalized()
			facing8 = _snap8(facing)
		still_acting = _action_timer > 0.0

	if still_acting:
		move_and_slide()
		if state == State.JUMP:
			_play_jump_visual()
		_update_jump_lift()
		_footstep_timer = 0.0
		if state != prev_state:
			state_changed.emit(state)
		return

	# A dodge that just finished this frame opens the short post-dodge dash-attack grace window
	# (order: "... or post-dodge window"). Reached exactly once per dodge, since the still_acting
	# branch above returns early on every frame the dodge is still in progress.
	if state == State.DODGE:
		_dash_grace_timer = dash_attack_post_grace
		_end_flicker_visual()

	# Not mid-action this frame (either never was, or the action just finished above with velocity
	# already correct) -> a buffered attack/dodge/jump takes priority over plain locomotion, then plain
	# locomotion, then idle decay. Exactly one of the three branches below runs.
	if _attack_buffer > 0.0 or _dodge_buffer > 0.0 or _jump_buffer > 0.0:
		if _attack_buffer >= _dodge_buffer and _attack_buffer >= _jump_buffer:
			_attack_buffer = 0.0
			_begin_attack("dash_attack" if _dash_grace_timer > 0.0 else "light1", input)
		elif _dodge_buffer >= _jump_buffer:
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
		if state == State.SPRINT:
			# Proximity "power level" sense: omnidirectional, no facing cone, no line-of-sight -- a
			# sprinting body is felt/loud, not just seen (see ProximitySense). Owner: "when naruto
			# running and near enemy ... player will auto detect and pull their kunai out".
			sensed_enemy = ProximitySense.nearest_in_radius(global_position, sense_radius(), "enemy", get_tree(), self)
			kunai_drawn = is_instance_valid(sensed_enemy)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		state = State.IDLE
	move_and_slide()
	_update_jump_lift()
	if state == State.DODGE:
		visual.play_action("dodge", facing8)
	elif state == State.JUMP:
		_play_jump_visual()
	elif _is_attack_state(state):
		visual.play_action(_attack_def.id, facing8)
	else:
		visual.set_pose(facing8, state == State.SPRINT, state != State.IDLE)
		if kunai_drawn:
			# Cosmetic overlay only: falls back silently to the normal sprint pose until an "kunai_ready"
			# animation exists in the active sprite set (PlayerVisual.play_action/has_action contract).
			visual.play_action("kunai_ready", facing8)
	if prev_state == State.JUMP and state != State.JUMP:
		dust.landing(global_position)
	_update_footsteps(delta)
	if state != prev_state:
		state_changed.emit(state)


## Shared horizontal air motion for JUMP and AIR_ATTACK: speed above `jump_air_speed_cap` is braked to
## the cap, held input steers toward `input * cap` at the air-control rate, and with no input a light
## drag settles the arc. Never applies an impulse, never zeroes velocity in one frame.
func _air_move(input: Vector2, delta: float) -> void:
	var speed := velocity.length()
	if speed > jump_air_speed_cap:
		velocity = velocity.normalized() * move_toward(speed, jump_air_speed_cap, jump_air_brake * delta)
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * jump_air_speed_cap, acceleration * air_control_mult * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, jump_air_drag * delta)


## Begin a dodge: direction comes from current input if any is held, else the last facing (order:
## "directional dodging based on current input or last facing direction"). Velocity jumps straight to
## the burst speed in that direction -- there is no separate "stop, then dodge" step.
func _begin_dodge(input: Vector2) -> void:
	var dir := input.normalized() if input != Vector2.ZERO else facing8
	facing8 = _snap8(dir)
	if input != Vector2.ZERO:
		facing = input.normalized()
	state = State.DODGE
	_action_duration = flicker_duration
	_action_timer = _action_duration
	velocity = Vector2.ZERO
	_flicker_moved = false
	_flicker_hidden = false
	flicker_count += 1
	_flicker_from = global_position
	_flicker_dir = facing8.normalized()
	visual.set_pose(facing8, false, false)
	# Depart burst at the start point now; the arrival burst is timed to the reappearance.
	_flicker_fx_pending = true


var _flicker_from: Vector2 = Vector2.ZERO
var _flicker_dir: Vector2 = Vector2.DOWN
var _flicker_fx_pending: bool = false


## Per-tick Body Flicker driver (called while State.DODGE): vanish + displace at `flicker_vanish_at`,
## reappear at `flicker_reappear_at`. Collision is respected by move_and_collide, so a wall just
## shortens the jump.
func _flicker_step() -> void:
	var elapsed := _action_duration - _action_timer
	if not _flicker_moved and elapsed >= flicker_vanish_at:
		_flicker_moved = true
		_flicker_hidden = true
		visual.visible = false
		move_and_collide(_flicker_dir * flicker_distance)
		var arrive_delay := maxf(flicker_reappear_at - elapsed, 0.0)
		if _flicker_fx_pending:
			_flicker_fx_pending = false
			BodyFlickerFx.spawn(get_parent(), _flicker_from, global_position, _flicker_dir, arrive_delay)
	if _flicker_hidden and elapsed >= flicker_reappear_at:
		_flicker_hidden = false
		visual.visible = true
		visual.set_pose(facing8, false, false)


## Safety net: the body is never left invisible once the dodge state is over.
func _end_flicker_visual() -> void:
	if _flicker_hidden:
		_flicker_hidden = false
		visual.visible = true


## Begin a jump. `velocity` is intentionally left untouched: whatever horizontal momentum the player
## already had carries straight into the air (order: "do not reset movement velocity when entering or
## exiting the jump state").
func _begin_jump() -> void:
	state = State.JUMP
	_action_duration = jump_duration if jump_duration > 0.0 else visual.action_duration("jump", jump_fallback_duration)
	_action_timer = _action_duration
	_play_jump_visual()
	dust.takeoff(global_position)


## Begin a fresh attack (light1, or a dash attack triggered from/near a dodge). `input`, when given
## and non-zero, re-aims the swing to the currently-held movement direction (so running into the
## attack button throws the hit the way you're moving, per "run -> attack" chaining) -- combo
## continuations call `_begin_attack` with Vector2.ZERO and skip this, keeping the chain's facing
## locked once it has started (see `_begin_next_combo_attack`).
## Velocity is never reset: `lunge` is ADDED to whatever velocity the player already had, exactly like
## a dodge's burst, so momentum from a run or a dodge carries straight into the swing.
func _begin_attack(attack_id: String, input: Vector2 = Vector2.ZERO) -> void:
	_end_flicker_visual()
	if input != Vector2.ZERO:
		facing = input.normalized()
		facing8 = _snap8(facing)
	_attack_def = _attack_table[attack_id]
	_combo_index = int(attack_id.substr(5)) if attack_id.begins_with("light") else 0
	state = _state_for_attack_id(attack_id)
	_attack_phase = AttackPhase.STARTUP
	_attack_timer = _attack_def.startup
	_hit_targets.clear()
	velocity += facing8 * _attack_def.lunge
	if state == State.AIR_ATTACK and not visual.has_action(attack_id):
		_play_jump_visual()  # no air_attack art yet: stay on the jump at its current phase
	else:
		visual.play_action(attack_id, facing8)


## Advance to the next hit in the light combo (wraps light3 -> light1, there is no light4), keeping
## the current facing8 locked rather than re-aiming from input -- order: "chain attacks without
## returning to idle", not "re-aim every hit of the chain".
func _begin_next_combo_attack() -> void:
	var next_index := _combo_index + 1
	if next_index > 3:
		next_index = 1
	_begin_attack("light%d" % next_index)


## Per-physics-frame update while `state` is one of the attack states. Startup/active/recovery timing,
## one-hit-per-swing registration, the combo-continue window, and the dodge-cancel-from-recovery window
## all live here.
func _process_attack_state(delta: float, input: Vector2) -> void:
	_attack_timer -= delta
	var airborne := state == State.AIR_ATTACK
	if airborne:
		_action_timer -= delta  # the jump keeps ticking underneath the swing
	# Weighty swordplay: on the ground velocity bleeds off toward 0 through the swing instead of being
	# steered by input or snapped to zero -- deliberate deceleration, never a hard reset. In the air
	# there is nothing to brake against: the jump arc's momentum is kept and input bends it at the
	# same air-control rate as a plain jump.
	if airborne:
		_air_move(input, delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if _attack_phase == AttackPhase.ACTIVE:
		_check_attack_hits()

	if _attack_phase == AttackPhase.RECOVERY:
		var elapsed := _attack_def.recovery - maxf(_attack_timer, 0.0)
		# Dodge-cancel: once recovery has committed past `dodge_cancel_from`, a fresh/buffered dodge
		# press interrupts the remaining recovery outright (order: "Interrupt...with a dodge").
		if not airborne and elapsed >= _attack_def.dodge_cancel_from and _dodge_buffer > 0.0:
			_dodge_buffer = 0.0
			_begin_dodge(input)
			move_and_slide()
			return
		# Combo continuation: a fresh/buffered attack press within `combo_window` of recovery starting
		# cuts the remaining recovery short and begins the next hit (order: "chain attacks without
		# returning to idle"). dash_attack's combo_window is 0 -- it never chains this way.
		if _attack_def.combo_window > 0.0 and elapsed <= _attack_def.combo_window and _attack_buffer > 0.0:
			_attack_buffer = 0.0
			_begin_next_combo_attack()
			move_and_slide()
			return

	if _attack_timer <= 0.0:
		_advance_attack_phase()
		if not _is_attack_state(state):
			if airborne and _action_timer > 0.0:
				# Swing finished while still in the air: hand back to the jump arc, momentum intact.
				state = State.JUMP
				move_and_slide()
				_update_jump_lift()
				return
			if airborne:
				visual.position.y = 0.0
				dust.landing(global_position)  # landed out of the swing
			# The attack just ended: pick the state up where locomotion already is this instant (order:
			# "continue running immediately after an attack ends" -- never a forced idle frame).
			var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
			if input != Vector2.ZERO:
				state = State.SPRINT if sprinting else State.MOVE
			else:
				state = State.IDLE
			move_and_slide()
			visual.set_pose(facing8, state == State.SPRINT, state != State.IDLE)
			return

	move_and_slide()
	if airborne:
		_update_jump_lift()
		# No dedicated air-attack art yet: keep showing the jump at its current phase (never the
		# placeholder, never a restart from frame 0) until Codex delivers `air_attack`.
		if not visual.has_action(_attack_def.id):
			_play_jump_visual()
			return
	visual.play_action(_attack_def.id, facing8)


## STARTUP -> ACTIVE -> RECOVERY -> (ends the attack). Only the final step can change `state` away
## from an attack state; the caller checks `_is_attack_state(state)` right after calling this.
func _advance_attack_phase() -> void:
	match _attack_phase:
		AttackPhase.STARTUP:
			_attack_phase = AttackPhase.ACTIVE
			_attack_timer = _attack_def.active
		AttackPhase.ACTIVE:
			_attack_phase = AttackPhase.RECOVERY
			_attack_timer = _attack_def.recovery
		AttackPhase.RECOVERY:
			_combo_index = 0
			state = State.IDLE  # placeholder; overwritten by the caller based on current input


## Manual geometric hit check (not Area2D/collision layers): reach + forward-arc test around facing8,
## against every node in the "enemy" group, each swing hitting a given enemy at most once. Chosen for
## direct testability (pure math) and because it satisfies "hitboxes register accurately in every
## supported direction" by construction -- the arc is defined in the same facing8 every other system uses.
func _check_attack_hits() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _hit_targets:
			continue
		if not (enemy.has_method("take_damage") and enemy.has_method("is_alive")):
			continue
		if not enemy.is_alive():
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist := to_enemy.length()
		if dist <= 0.0 or dist > _attack_def.reach:
			continue
		var angle_diff := rad_to_deg(absf(facing8.angle_to(to_enemy)))
		if angle_diff > _attack_def.arc_half_angle_deg:
			continue
		_hit_targets.append(enemy)
		enemy.take_damage(_attack_def.damage, to_enemy.normalized(), _attack_def.knockback, _attack_def.hitstop_ms)
		_hitstop_timer = maxf(_hitstop_timer, _attack_def.hitstop_ms / 1000.0)


func _state_for_attack_id(attack_id: String) -> State:
	match attack_id:
		"light1":
			return State.LIGHT1
		"light2":
			return State.LIGHT2
		"light3":
			return State.LIGHT3
		"air_attack":
			return State.AIR_ATTACK
		_:
			return State.DASH_ATTACK


static func _is_attack_state(s: State) -> bool:
	return s == State.LIGHT1 or s == State.LIGHT2 or s == State.LIGHT3 or s == State.DASH_ATTACK or s == State.AIR_ATTACK


## Periodic dirt-puff bursts while running on the ground (MOVE/SPRINT only). Timer resets to 0 by the
## still-acting path above whenever a dodge/jump is in progress, so running resumes with an immediate
## puff on the first step out of an action rather than waiting out a stale interval.
func _update_footsteps(delta: float) -> void:
	if state != State.MOVE and state != State.SPRINT:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		dust.footstep(global_position, state == State.SPRINT, facing)
		_footstep_timer = (footstep_interval_sprint if state == State.SPRINT else footstep_interval_walk) * randf_range(0.8, 1.25)


## Visual-only elevation arc for the current jump (0 outside JUMP). Applied to PlayerVisual's local
## position -- never to this body's position -- so the logical ground position used for collision and
## the arena's Y-sort (keyed off this node's own global_position.y, see arena_sort.gd) never moves.
## Jump art frame follows the jump's own progress, so it is phase-correct through an air attack.
func _play_jump_visual() -> void:
	var progress := 0.0 if _action_duration <= 0.0 else 1.0 - _action_timer / _action_duration
	visual.play_action_progress("jump", facing8, progress)


func _update_jump_lift() -> void:
	if (state != State.JUMP and state != State.AIR_ATTACK) or _action_duration <= 0.0:
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


## True while the current action is a real evasion: a dodge, or airborne (jump / air attack).
func is_evading_melee() -> bool:
	return state == State.DODGE or state == State.JUMP or state == State.AIR_ATTACK


## Enemy melee entry point. Returns true if the hit landed. A dodge or jump evades it completely; a
## hit that lands only tints the figure and adds a small shove -- control is never taken away.
func take_hit(damage: float, from_dir: Vector2, shove: float = 180.0) -> bool:
	if is_evading_melee() or _hit_invuln > 0.0:
		return false
	hits_taken += 1
	_hit_invuln = HIT_INVULN_TIME
	hit_flash_timer = HIT_FLASH_TIME
	visual.modulate = HIT_TINT
	velocity += from_dir.normalized() * shove
	hit_taken.emit(damage, from_dir)
	health = maxf(health - maxf(damage, 0.0), 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		times_downed += 1
		downed.emit()
		restore_health(max_health)
	return true


## Adds health (clamped to max_health). Returns the amount actually restored.
func restore_health(amount: float) -> float:
	var before := health
	health = clampf(health + maxf(amount, 0.0), 0.0, max_health)
	if health != before:
		health_changed.emit(health, max_health)
	return health - before


func reset_camera() -> void:
	camera.reset_smoothing()

## World-px radius of the proximity "power level" sense (see `_update_proximity_sense` note in
## _physics_process): how far away a nearby enemy is auto-detected while sprinting ("naruto running").
func sense_radius() -> float:
	return ProximitySense.radius_for(intelligence)


## Removes up to `amount` ryo (clamped to what is actually carried) and returns the amount actually
## removed. Called by an enemy's steal action (see Bandit._steal_ryo); emits ryo_changed when it changes.
func lose_ryo(amount: int) -> int:
	var taken := clampi(amount, 0, ryo)
	if taken > 0:
		ryo -= taken
		ryo_changed.emit(ryo)
	return taken


func get_state_name() -> String:
	return State.keys()[state]


## Which transitions are legal RIGHT NOW. One source of truth for the dev overlay and the tests; the
## live logic in _physics_process/_process_attack_state applies the same rules.
func cancel_eligibility() -> Dictionary:
	var e := {"combo": false, "dodge_cancel": false, "dash_attack": false, "air_attack": false}
	if _is_attack_state(state) and _attack_phase == AttackPhase.RECOVERY and _attack_def != null:
		var elapsed := _attack_def.recovery - maxf(_attack_timer, 0.0)
		e.combo = _attack_def.combo_window > 0.0 and elapsed <= _attack_def.combo_window
		e.dodge_cancel = state != State.AIR_ATTACK and elapsed >= _attack_def.dodge_cancel_from
	e.dash_attack = (state == State.DODGE and _action_timer <= dash_attack_late_window) or _dash_grace_timer > 0.0
	e.air_attack = state == State.JUMP
	return e


## Dev-diagnostics snapshot (state, attack phase, combo index, live buffers, cancel permissions).
func debug_snapshot() -> Dictionary:
	return {
		"state": get_state_name(),
		"phase": AttackPhase.keys()[_attack_phase] if _is_attack_state(state) else "-",
		"combo": _combo_index,
		"attack_buffer": _attack_buffer,
		"dodge_buffer": _dodge_buffer,
		"jump_buffer": _jump_buffer,
		"hitstop": _hitstop_timer,
		"cancel": cancel_eligibility(),
	}


## Snap a direction to one of 8 unit-ish headings (diagonals normalized).
static func _snap8(dir: Vector2) -> Vector2:
	var idx := int(roundf(dir.angle() / (PI / 4.0)))
	return Vector2.from_angle(idx * (PI / 4.0)).snapped(Vector2(0.01, 0.01))
