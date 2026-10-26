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
## Milestone B reusable combat events. `attack_event` fires at each authored marker of the active swing
## ("startup","active","recovery","combo_open","combo_close","cancel_open","end"); `attack_hit` fires ONCE per
## confirmed contact with a HitEvent -- sparks, silhouettes, slash arcs, audio and diagnostics all listen here.
signal attack_event(event_name: String, attack_id: String)
signal attack_hit(hit: HitEvent)
signal hit_taken(damage: float, from_dir: Vector2)
signal health_changed(current: float, maximum: float)
signal chakra_changed(current: float, maximum: float)
## Substitution charges (shown as pips on the HUD). Only the stat exists so far; the Substitution jutsu will spend them.
signal substitution_changed(charges: int, maximum: int)
signal downed  ## health reached 0 (the player is respawned at the spawn point at full health right after; there is no death screen yet)
signal respawned(at: Vector2)  ## emitted after a respawn has put the player back at `spawn_position`
## Currency changed (spent, or stolen by an enemy via lose_ryo() -- see Bandit._steal_ryo/is_worth_robbing).
## No player death/HP system exists here (locked RPG rules); this only tracks the stat.
signal ryo_changed(new_amount: int)

enum State { IDLE, MOVE, SPRINT, DODGE, JUMP, LIGHT1, LIGHT2, LIGHT3, DASH_ATTACK, AIR_ATTACK, CHARGE }
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
## Body Flicker dodge = the evade burst: the body stays visible and bursts `flicker_distance` px along the
## dodge heading over `flicker_burst_time` (walls stop it) with the ninja_evade streak on top, then stands
## still. Invulnerable for the whole `flicker_duration`.
@export var flicker_distance: float = 150.0
@export var flicker_duration: float = 0.30
@export var flicker_burst_time: float = 0.20  ## how long the burst lasts (speed = flicker_distance / this)
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
## Logical height above the ground (shrine stairs and platform, see ShrineElevation). The ground position is
## unchanged by it; only the figure is drawn higher: visual_y = ground_y - elevation (a jump adds its own lift).
var elevation: float = 0.0
var camera_baseline: float = WorldScale.CAMERA_BASE_ZOOM  ## zoom of the active CameraPreset for the current figure
var _action_timer: float = 0.0  ## seconds left in the current dodge/jump; 0 when not acting
var _action_duration: float = 0.0  ## total authored length of the current/last action, for progress math
var chidori_phase: ChidoriPhase = ChidoriPhase.NONE
var chidori_t := 0.0
var chidori_cd := 0.0
var chidori_dir := Vector2.DOWN
var chidori_hits: Array[Node] = []  ## enemies already struck by this rush (each is hit at most once)
var chidori_count := 0
var chidori_fx: ChidoriFx
var _chidori_start := Vector2.ZERO
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
var _hit_confirmed: bool = false  ## the current swing has connected (opens hit-confirm follow-ups)
var _swing_clock: float = 0.0  ## seconds since the current swing began (drives the event markers)
var _fired_markers: Dictionary = {}  ## marker name -> true once emitted for the current swing
var _hitstop_timer: float = 0.0  ## local-only pause (not Engine.time_scale): see _physics_process top
const MAX_HEALTH := 100.0
var max_health: float = MAX_HEALTH
var health: float = MAX_HEALTH
var times_downed: int = 0
var spawn_position: Vector2 = Vector2.ZERO  ## where a downed player comes back; defaults to where the player started (set in _ready)
const RESPAWN_INVULN := 1.5  ## grace after a respawn so enemies camping the spawn cannot instantly chain-down the player
const RESPAWN_FADE_IN := 0.5
var respawn_count: int = 0
const MAX_CHAKRA := 100.0
const MAX_SUBSTITUTIONS := 3
var max_chakra: float = MAX_CHAKRA
var chakra: float = MAX_CHAKRA
## Provisional chakra recovery while holding charge; no aura is bound yet.
@export var chakra_charge_per_second: float = 20.0
## Ninjas run on water, paying chakra for every second spent over it. Out of chakra they slip under and are
## put back on the last dry spot, taking a small hit.
@export var water_chakra_per_second: float = 10.0
const WATER_SINK_DAMAGE := 8.0
var _last_dry := Vector2.ZERO
var over_water := false
var _charge_interrupted := false
const CHARGE_HOLD_DELAY := 0.30  ## press keeps existing substitution; sustained L2 adds charge
var _charge_hold_time := 0.0
var max_substitution_charges: int = MAX_SUBSTITUTIONS
var substitution_charges: int = MAX_SUBSTITUTIONS
## Substitution Jutsu (L2). A timed L2 press only pays off if an enemy attack lands inside the window.
## Each success spends one charge and starts that charge's OWN cooldown; the others stay usable.
signal substitution_triggered(old_pos: Vector2, new_pos: Vector2)
const SUB_WINDOW := 0.25  ## L2 pressed up to this long BEFORE a hit lands counts as a timed evade
const SUB_COOLDOWN := 20.0  ## per-charge recharge seconds (set to 20 by the designer)
const SUB_INVULN := 0.5  ## grace after a substitution so a simultaneous second hit cannot land
const SUB_BEHIND_DIST := 72.0  ## how far behind the attacker the player reappears
var _sub_buffer: float = 0.0
var _sub_cooldowns: Array[float] = []  ## remaining seconds of each spent charge
var _sub_reveal: float = 0.0  ## > 0 while the body is concealed between log swap and reappearance
var substitution_count: int = 0
var flicker_count: int = 0
var hits_taken: int = 0  ## enemy hits that landed on the player (read by tests / web smoke state)
var hit_flash_timer: float = 0.0
var _hit_invuln: float = 0.0  ## brief grace after a hit so one combo cannot chain-stun the player
const HIT_INVULN_TIME := 0.45
## Damage reactions (Codex clips: hit_react 0.333 s, knockback 0.5 s, death 0.667 s). Gameplay owns the
## world displacement; the art has zero root motion.
const HURT_CLIP := 0.333
const KNOCKBACK_CLIP := 0.5
const DEATH_CLIP := 0.667
const DEATH_HOLD := 0.65  ## prone hold after the clip, before the respawn
const KNOCKBACK_SHOVE := 170.0  ## shoves at least this strong (melee) play the knockback clip
## Off in the default suite where tests assume the instant respawn; the dedicated damage test turns it on.
static var death_sequence_enabled: bool = true
var hurt_kind: String = ""  ## "" | hit_react | knockback
var _hurt_t: float = 0.0
var _hurt_dur: float = 0.333
var dying: bool = false
var _death_t: float = 0.0
const HIT_FLASH_TIME := 0.18
const HIT_TINT := Color(1.0, 0.45, 0.4, 1.0)

## -- Proximity sense ("naruto running" auto-detect) --
var sensed_enemy: Node2D = null  ## nearest enemy inside the sense circle this frame while SPRINTing, else null
var kunai_drawn: bool = false  ## true the instant `sensed_enemy` is non-null (read by tests / web smoke state)

## -- Inventory (D-pad slots) --
## What the player carries and which D-pad / R2 slot holds what. A D-pad press (or the arrow keys) uses that slot's item.
var inventory := PlayerInventory.new()
signal item_used(item_id: String)
const THROW_TIME := 0.34  ## total kunai throw (wind-up, release, follow-through)
const THROW_RELEASE := 0.4  ## fraction of THROW_TIME at which the kunai leaves the hand
const THROW_MOVE_MULT := 0.35  ## walk/run speed multiplier while the arm is busy
const THROW_HAND := Vector2(0, 0)

## Chidori (R2 + Square): charge in place, rush forward, burst on the first enemy or wall. Costs chakra.
enum ChidoriPhase { NONE, CHARGE, RUSH, RECOVER }
const CHIDORI_CHARGE_TIME := 0.65
const CHIDORI_RUSH_SPEED := 720.0
const CHIDORI_RUSH_MAX := 380.0
const CHIDORI_RECOVER_TIME := 0.28
const CHIDORI_COST := 25.0
const CHIDORI_COOLDOWN := 1.2
const CHIDORI_DAMAGE := 55.0
const CHIDORI_SPLASH_DAMAGE := 22.0
const CHIDORI_SPLASH_RADIUS := 110.0
const CHIDORI_KNOCKBACK := 520.0
const CHIDORI_CONTACT := 46.0
const CHIDORI_HITSTOP_MS := 110.0
var _throw_t: float = 0.0  ## seconds left in the current throw (0 = not throwing)
var _throw_released: bool = true
var _throw_dir: Vector2 = Vector2.DOWN
var _throw_item := "kunai"  ## inventory id of what the current throw releases ("kunai" or "paper_tag")
var tags_thrown_count: int = 0
var kunai_thrown_count: int = 0

@onready var visual: PlayerVisual = $PlayerVisual
@onready var camera: Camera2D = $Camera2D
@onready var dust: DustPuff = $DustPuff


func _ready() -> void:
	add_to_group("player")
	_last_dry = global_position
	collision_mask |= ShrineElevation.EDGE_LAYER  # platform rim and stair sides only stop the player
	spawn_position = global_position
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
	var hit_fx := HitFx.new()
	hit_fx.name = "HitFx"
	add_child(hit_fx)
	hit_fx.bind(self)
	var bar := HealthBar.new()
	bar.name = "HealthBar"
	add_child(bar)
	bar.bind(self)
	inventory.load_saved()
	var menu := PlayerMenu.new()
	menu.name = "PlayerMenu"
	add_child(menu)
	menu.bind(self)


func _tick_water(delta: float) -> void:
	over_water = not dying and BlightwoodWater.over_water(get_tree(), global_position)
	if not over_water:
		_last_dry = global_position
		return
	if chakra > 0.0:
		chakra = maxf(chakra - water_chakra_per_second * delta, 0.0)
		chakra_changed.emit(chakra, max_chakra)
	else:
		over_water = false
		global_position = _last_dry
		velocity = Vector2.ZERO
		take_hit(WATER_SINK_DAMAGE, Vector2.ZERO, 0.0)


func _physics_process(delta: float) -> void:
	_tick_water(delta)
	var prev_state := state
	_follow_elevation(delta)
	var charge_held := Input.is_action_pressed("substitution")
	_charge_hold_time = _charge_hold_time + delta if charge_held else 0.0
	if not charge_held and not Input.is_action_pressed("chakra_charge"):
		_charge_interrupted = false
	# Cleared every frame, only re-populated below in the plain-SPRINT locomotion branch: sensing is a
	# fresh, every-frame read, never a sticky flag that survives into dodge/attack/jump/idle frames.
	sensed_enemy = null
	kunai_drawn = false
	_hit_invuln = maxf(_hit_invuln - delta, 0.0)
	_tick_substitution(delta)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
		visual.modulate = HIT_TINT if hit_flash_timer > 0.0 else Color.WHITE

	# Presses are captured EVERY physics tick, including hitstop ticks (Milestone A fluidity order:
	# "buffered inputs must survive hitstop"). Before this, a press landing inside the 3-4 tick
	# freeze was silently dropped.
	var jutsu_held := Input.is_action_pressed("jutsu_modifier")
	chidori_cd = maxf(chidori_cd - delta, 0.0)
	if Input.is_action_just_pressed("dodge") and not (jutsu_held and _jutsu_press("circle")):
		_dodge_buffer = input_buffer_window
	if Input.is_action_just_pressed("jump") and not (jutsu_held and _jutsu_press("cross")):
		_jump_buffer = input_buffer_window
	if Input.is_action_just_pressed("attack_light") and not (jutsu_held and _jutsu_press("square")):
		_attack_buffer = input_buffer_window
	if Input.is_action_just_pressed("substitution"):
		_sub_buffer = SUB_WINDOW
	for slot: String in PlayerInventory.DPAD_SLOTS:
		if Input.is_action_just_pressed("slot_" + slot):
			use_slot(slot)
	_tick_throw(delta)

	# Local hitstop: pause this body's own velocity/position integration only -- NOT Engine.time_scale
	# (the order forbids a global freeze). Buffers do not decay while frozen, so a press made just
	# before or during the freeze is still live the instant it ends, and attack/cancel windows resume
	# exactly where they stopped.
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer - delta, 0.0)
		return

	if dying:
		_tick_dying(delta)
		return
	if _hurt_t > 0.0:
		_cancel_chidori()
		_tick_hurt(delta)
		return
	if chidori_phase != ChidoriPhase.NONE:
		_tick_chidori(delta)
		return

	_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_dash_grace_timer = maxf(_dash_grace_timer - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	var target_speed := sprint_speed if sprinting else walk_speed
	if _throw_t > 0.0:
		target_speed *= THROW_MOVE_MULT

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
			# Evade burst: constant speed along the heading for `flicker_burst_time`, then stop dead.
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
	elif (Input.is_action_pressed("chakra_charge") or _charge_hold_time >= CHARGE_HOLD_DELAY) and not _charge_interrupted and _sub_reveal <= 0.0:
		_process_charge(delta)
	elif input != Vector2.ZERO:
		velocity = velocity.move_toward(input * target_speed, acceleration * delta)
		facing = input.normalized()
		var strafe := lock_aim_dir()
		if strafe != Vector2.ZERO and not sprinting:
			facing = strafe  # locked on: walk around the target while still facing it
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
		var face_lock := lock_aim_dir()
		if face_lock != Vector2.ZERO and _throw_t <= 0.0:
			facing = face_lock
			facing8 = _snap8(face_lock)
	move_and_slide()
	_update_jump_lift()
	if state == State.DODGE:
		visual.play_action("dodge", facing8)
	elif state == State.JUMP:
		_play_jump_visual()
	elif _is_attack_state(state):
		visual.play_action(_attack_def.id, facing8)
	elif state == State.CHARGE:
		visual.play_action("charge", facing8)
	else:
		visual.set_pose(facing8, state == State.SPRINT, state != State.IDLE)
		if _throw_t > 0.0:
			_play_throw_visual()
		elif kunai_drawn:
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
	flicker_count += 1
	_flicker_from = global_position
	_flicker_dir = facing8.normalized()
	visual.set_pose(facing8, false, false)
	EvadeStreakFx.spawn(self, _flicker_dir)


var _flicker_from: Vector2 = Vector2.ZERO
var _flicker_dir: Vector2 = Vector2.DOWN


## Per-tick evade-burst driver (called while State.DODGE): constant velocity along the heading during the
## burst, zero afterwards. Walls stop the body through the normal move_and_slide.
func _flicker_step() -> void:
	var elapsed := _action_duration - _action_timer
	if elapsed < flicker_burst_time:
		velocity = _flicker_dir * (flicker_distance / flicker_burst_time)
	else:
		velocity = Vector2.ZERO


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
	if input != Vector2.ZERO:
		facing = input.normalized()
		facing8 = _snap8(facing)
	var lock_dir := lock_aim_dir()
	if lock_dir != Vector2.ZERO:
		facing = lock_dir  # locked on: every swing (and every combo hit) turns to the target
		facing8 = _snap8(lock_dir)
	_attack_def = _attack_table[attack_id]
	_combo_index = int(attack_id.substr(5)) if attack_id.begins_with("light") else 0
	state = _state_for_attack_id(attack_id)
	_attack_phase = AttackPhase.STARTUP
	_attack_timer = _attack_def.startup
	_hit_targets.clear()
	_hit_confirmed = false
	_swing_clock = 0.0
	_fired_markers.clear()
	velocity += facing8 * _attack_def.lunge
	if _attack_def.displacement_cap > 0.0 and velocity.length() > _attack_def.displacement_cap:
		velocity = velocity.limit_length(_attack_def.displacement_cap)
	if state == State.AIR_ATTACK and not visual.has_action(attack_id):
		_play_jump_visual()  # no air_attack art yet: stay on the jump at its current phase
	else:
		visual.play_action(attack_id, facing8)


## Advance to the next hit in the light combo (wraps light3 -> light1, there is no light4), keeping
## the current facing8 locked rather than re-aiming from input -- order: "chain attacks without
## returning to idle", not "re-aim every hit of the chain".
func _begin_next_combo_attack() -> void:
	var next_id: String = _attack_def.chains_to
	if next_id == "" or not _attack_table.has(next_id):
		return  # finisher: nothing to chain into (the callers check combo_window_for first)
	_begin_attack(next_id)


## Per-physics-frame update while `state` is one of the attack states. Startup/active/recovery timing,
## one-hit-per-swing registration, the combo-continue window, and the dodge-cancel-from-recovery window
## all live here.
func _process_attack_state(delta: float, input: Vector2) -> void:
	_attack_timer -= delta
	_swing_clock += delta
	_emit_due_markers()
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
		var cancel_from := _attack_def.dodge_cancel_from_for(_hit_confirmed)
		if not airborne and cancel_from >= 0.0 and elapsed >= cancel_from and _dodge_buffer > 0.0:
			_dodge_buffer = 0.0
			_begin_dodge(input)
			move_and_slide()
			return
		# Combo continuation: a fresh/buffered attack press within `combo_window` of recovery starting
		# cuts the remaining recovery short and begins the next hit (order: "chain attacks without
		# returning to idle"). dash_attack's combo_window is 0 -- it never chains this way.
		var chain_window := _attack_def.combo_window_for(_hit_confirmed)
		if chain_window > 0.0 and elapsed <= chain_window and _attack_buffer > 0.0:
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
				visual.position.y = -elevation
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


## Emit every authored marker whose time has been reached, once each per swing.
func _emit_due_markers() -> void:
	if _attack_def == null:
		return
	for m: Dictionary in _attack_def.event_markers():
		var n: String = m.name
		if _fired_markers.has(n):
			continue
		var t: float = m.t
		if n == "cancel_open":
			var cf := _attack_def.dodge_cancel_from_for(_hit_confirmed)
			if cf < 0.0:
				continue
			t = _attack_def.startup + _attack_def.active + cf
		elif n == "combo_close":
			t = _attack_def.startup + _attack_def.active + _attack_def.combo_window_for(_hit_confirmed)
		if _swing_clock + 0.000001 >= t:
			_fired_markers[n] = true
			attack_event.emit(n, _attack_def.id)


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
			if not _fired_markers.has("end"):
				_fired_markers["end"] = true
				attack_event.emit("end", _attack_def.id)
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
		if not Combatants.same_level(self, enemy):
			continue  # a blade cannot reach up a cliff or down off a landing
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist := to_enemy.length()
		if dist <= 0.0 or dist > _attack_def.reach:
			continue
		var angle_diff := rad_to_deg(absf(facing8.angle_to(to_enemy)))
		if angle_diff > _attack_def.arc_half_angle_deg:
			continue
		_hit_targets.append(enemy)
		_hit_confirmed = true
		enemy.take_damage(_attack_def.damage, to_enemy.normalized(), _attack_def.knockback, _attack_def.hitstop_ms)
		_hitstop_timer = maxf(_hitstop_timer, _attack_def.hitstop_ms / 1000.0)
		attack_hit.emit(HitEvent.make(self, enemy, _attack_def, to_enemy.normalized(), _combo_index))


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


## Eases `elevation` toward the height of the ground under the feet and carries the figure and camera with it.
func _follow_elevation(delta: float) -> void:
	var before := elevation
	ShrineElevation.update_actor(self, delta)
	if elevation != before:
		_update_jump_lift()
		camera.position.y = -elevation


func _update_jump_lift() -> void:
	if (state != State.JUMP and state != State.AIR_ATTACK) or _action_duration <= 0.0:
		visual.position.y = -elevation
		return
	var progress := clampf(1.0 - (_action_timer / _action_duration), 0.0, 1.0)
	visual.position.y = -elevation - jump_visual_height * sin(progress * PI)


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


## Planted charge hold. Called only after grounded actions have completed; attack/dodge/jump
## keep priority. Animation runs at the approved 6FPS through the normal SpriteActor clock.
func _process_charge(delta: float) -> void:
	state = State.CHARGE
	velocity = Vector2.ZERO
	_footstep_timer = 0.0
	visual.position.y = -elevation
	visual.play_action("charge", facing8)
	var restored := minf(max_chakra, chakra + chakra_charge_per_second * delta)
	if not is_equal_approx(restored, chakra):
		chakra = restored
		chakra_changed.emit(chakra, max_chakra)


## Enemy melee entry point. Returns true if the hit landed. A dodge or jump evades it completely.
func take_hit(damage: float, from_dir: Vector2, shove: float = 180.0, attacker: Variant = null) -> bool:
	if dying or is_evading_melee() or _hit_invuln > 0.0:
		return false
	if _try_substitution(attacker, from_dir):
		return false
	hits_taken += 1
	_cancel_chidori()
	if state == State.CHARGE:
		state = State.IDLE
		_charge_interrupted = true  # release before starting another charge after being hit
		visual.set_pose(facing8, false, false)
	_hit_invuln = HIT_INVULN_TIME
	hit_flash_timer = HIT_FLASH_TIME
	visual.modulate = HIT_TINT
	velocity += from_dir.normalized() * shove
	hit_taken.emit(damage, from_dir)
	health = maxf(health - maxf(damage, 0.0), 0.0)
	health_changed.emit(health, max_health)
	var dir := from_dir.normalized() if from_dir != Vector2.ZERO else -facing
	if health <= 0.0:
		times_downed += 1
		downed.emit()
		if death_sequence_enabled:
			_begin_dying(dir, shove)
		else:
			respawn()
	else:
		_begin_hurt(dir, shove)
	return true


func _clear_action_for_damage() -> void:
	state = State.IDLE
	_action_timer = 0.0
	_attack_timer = 0.0
	_attack_def = null
	_combo_index = 0
	_hit_targets.clear()
	_dodge_buffer = 0.0
	_jump_buffer = 0.0
	_attack_buffer = 0.0


## Struck: the attack/dodge/charge is cancelled, the body is thrown away from the hit and plays the
## hit_react clip (light hit) or the knockback clip (strong melee shove), keeping its facing.
func _begin_hurt(dir: Vector2, shove: float) -> void:
	_clear_action_for_damage()
	var big := shove >= KNOCKBACK_SHOVE
	hurt_kind = "knockback" if big else "hit_react"
	_hurt_dur = KNOCKBACK_CLIP if big else HURT_CLIP
	_hurt_t = _hurt_dur
	velocity = dir * shove * (2.8 if big else 2.2)
	CameraImpact.impulse(dir, 7.0 if big else 4.0, 180.0 if big else 120.0)
	dust.landing(global_position)
	_show_damage_clip(hurt_kind, 0.0)


func _tick_hurt(delta: float) -> void:
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	# Decelerate so the body skids to a stop around 70% through the clip, then stands recovered.
	var remaining := maxf(_hurt_dur * 0.7 - (_hurt_dur - _hurt_t), 0.02)
	velocity = velocity.move_toward(Vector2.ZERO, velocity.length() / remaining * delta)
	move_and_slide()
	_show_damage_clip(hurt_kind, 1.0 - _hurt_t / _hurt_dur)
	if _hurt_t <= 0.0:
		hurt_kind = ""
		velocity = Vector2.ZERO


## Fatal blow: throw the body, play the death clip, hold the prone last frame, then respawn.
func _begin_dying(dir: Vector2, shove: float) -> void:
	_clear_action_for_damage()
	_hurt_t = 0.0
	hurt_kind = ""
	dying = true
	_death_t = 0.0
	_hit_invuln = DEATH_CLIP + DEATH_HOLD + 1.0
	velocity = dir * maxf(shove, 140.0) * 3.0
	CameraImpact.impulse(dir, 11.0, 260.0)
	dust.landing(global_position)
	_show_damage_clip("death", 0.0)


func _tick_dying(delta: float) -> void:
	_death_t += delta
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_show_damage_clip("death", clampf(_death_t / DEATH_CLIP, 0.0, 1.0))
	var fade_start := DEATH_CLIP + DEATH_HOLD - 0.3
	if _death_t > fade_start:
		visual.modulate.a = clampf(1.0 - (_death_t - fade_start) / 0.3, 0.0, 1.0)
	if _death_t >= DEATH_CLIP + DEATH_HOLD:
		dying = false
		respawn()


func _show_damage_clip(kind: String, progress: float) -> void:
	if not visual.play_action_progress(kind, facing8, progress):
		visual.set_pose(facing8, false, false)


## 0..1 refill of the charge that comes back first (1.0 when no charge is recharging). Drives the HUD slot.
func substitution_progress() -> float:
	if _sub_cooldowns.is_empty():
		return 1.0
	var soonest: float = _sub_cooldowns[0]
	for c in _sub_cooldowns:
		soonest = minf(soonest, c)
	return clampf(1.0 - soonest / SUB_COOLDOWN, 0.0, 1.0)


func _tick_substitution(delta: float) -> void:
	_sub_buffer = maxf(_sub_buffer - delta, 0.0)
	if _sub_reveal > 0.0:
		_sub_reveal = maxf(_sub_reveal - delta, 0.0)
		if _sub_reveal <= 0.0:
			visual.visible = true
	if _sub_cooldowns.is_empty():
		return
	var before := _sub_cooldowns.size()
	for i in range(_sub_cooldowns.size() - 1, -1, -1):
		_sub_cooldowns[i] -= delta
		if _sub_cooldowns[i] <= 0.0:
			_sub_cooldowns.remove_at(i)
	if _sub_cooldowns.size() != before:
		substitution_charges = max_substitution_charges - _sub_cooldowns.size()
		substitution_changed.emit(substitution_charges, max_substitution_charges)


## Confirmed timed L2 evade: only reached from take_hit, i.e. an attack that would really have landed.
## One call per attack, so one proc per attack. Returns true if the hit was swallowed by a log swap.
func _try_substitution(attacker: Variant, from_dir: Vector2) -> bool:
	if _sub_buffer <= 0.0 or substitution_charges <= 0 or _sub_cooldowns.size() >= max_substitution_charges:
		return false
	var old := global_position
	var dest := _substitution_destination(attacker, from_dir)
	_sub_buffer = 0.0
	_sub_cooldowns.append(SUB_COOLDOWN)
	substitution_charges = max_substitution_charges - _sub_cooldowns.size()
	substitution_changed.emit(substitution_charges, max_substitution_charges)
	substitution_count += 1
	_hit_invuln = SUB_INVULN
	global_position = dest
	velocity = Vector2.ZERO
	if _attacker_alive(attacker):
		var to_att := (attacker as Node2D).global_position - dest
		if to_att.length() > 1.0:
			facing8 = _snap8(to_att)
			visual.set_pose(facing8, false, false)
	visual.visible = false
	_sub_reveal = SubstitutionFx.ARRIVAL_DELAY
	SubstitutionFx.spawn(get_parent(), old, dest)
	substitution_triggered.emit(old, dest)
	return true


## Spot behind the attacker (opposite side from where the player stood). Validated against walls and the
## arena bounds; shrinks the distance and swings the angle before giving up and staying in place (the
## log swap still happens, just without the reposition). A dead / freed attacker also means "stay".
func _substitution_destination(attacker: Variant, from_dir: Vector2) -> Vector2:
	if not _attacker_alive(attacker):
		return global_position
	var toward := global_position - (attacker as Node2D).global_position
	if toward.length() < 1.0:
		toward = from_dir if from_dir.length() > 0.01 else Vector2(1, 1)
	var behind := -toward.normalized()
	for dist in [SUB_BEHIND_DIST, SUB_BEHIND_DIST * 0.7, SUB_BEHIND_DIST * 0.5]:
		for ang in [0.0, 0.5, -0.5, 1.0, -1.0]:
			var p: Vector2 = (attacker as Node2D).global_position + behind.rotated(ang) * dist
			if _substitution_spot_ok(p):
				return p
	return global_position


## Attackers can be freed mid-flight (killed bandit, expired thrower), so they travel as untyped Variants.
static func _attacker_alive(attacker: Variant) -> bool:
	return is_instance_valid(attacker) and attacker is Node2D and not (attacker as Node2D).is_queued_for_deletion()


func _substitution_spot_ok(p: Vector2) -> bool:
	var arena := get_parent()
	if arena != null and arena.has_method("get_bounds"):
		var b: Rect2 = arena.get_bounds()
		if not b.grow(-8.0).has_point(p):
			return false
	if absf(ShrineElevation.target_at(p) - elevation) > ShrineElevation.HEIGHT * ShrineElevation.BOARD_AT:
		return false  # never swap across the shrine's levels (onto the platform from the ground, or off it)
	return not test_move(Transform2D(0.0, p), Vector2(0.01, 0.0))


## Adds health (clamped to max_health). Returns the amount actually restored.
## Puts a downed player back at `spawn_position` with full health, no leftover motion / action / combo
## state and a short grace period. Safe to call any time (the hit path calls it when health reaches 0).
func respawn() -> void:
	dying = false
	_death_t = 0.0
	_hurt_t = 0.0
	hurt_kind = ""
	_charge_interrupted = true
	dust.landing(global_position)
	global_position = spawn_position
	velocity = Vector2.ZERO
	state = State.IDLE
	_action_timer = 0.0
	_dodge_buffer = 0.0
	_jump_buffer = 0.0
	_attack_buffer = 0.0
	_sub_buffer = 0.0
	_sub_reveal = 0.0
	_attack_timer = 0.0
	_attack_def = null
	_combo_index = 0
	_hit_targets.clear()
	_dash_grace_timer = 0.0
	_hitstop_timer = 0.0
	_footstep_timer = 0.0
	hit_flash_timer = 0.0
	visual.visible = true
	_hit_invuln = RESPAWN_INVULN
	var base := Color.WHITE
	visual.modulate = Color(base.r, base.g, base.b, 0.0)
	create_tween().tween_property(visual, "modulate:a", 1.0, RESPAWN_FADE_IN)
	restore_health(max_health)
	reset_camera()
	dust.landing(global_position)
	respawn_count += 1
	respawned.emit(global_position)


## Adds chakra (clamped to max_chakra). Returns the amount actually restored.
func restore_chakra(amount: float) -> float:
	var before := chakra
	chakra = clampf(chakra + maxf(amount, 0.0), 0.0, max_chakra)
	if chakra != before:
		chakra_changed.emit(chakra, max_chakra)
	return chakra - before


## Uses whatever sits on D-pad slot `slot` ("up"/"right"/"down"/"left"). Returns true when something happened.
func use_slot(slot: String) -> bool:
	var id := inventory.slot_item(slot)
	if id == "" or health <= 0.0:
		return false
	var used := false
	match id:
		"health_gourd":
			if health < max_health and inventory.consume(id):
				var before := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
				restore_health(max_health * HealthGourd.FRACTION)
				var bar := get_node_or_null("HealthBar") as HealthBar
				if bar != null:
					bar.begin_heal_anim(before, 0.0)
				used = true
		"chakra_gourd":
			if chakra < max_chakra and inventory.consume(id):
				restore_chakra(max_chakra * HealthGourd.FRACTION)
				used = true
		"kunai":
			used = _begin_throw()
		"paper_tag", "tag_bomb", "smoke_tag_bomb":
			used = _begin_throw(id)
	if used:
		item_used.emit(id)
	return used


## Unit vector from the player to the R3 lock-on target, or ZERO when nothing is locked.
func lock_aim_dir() -> Vector2:
	var lock := get_node_or_null("LockOn") as PlayerLockOn
	return lock.aim_direction() if lock != null else Vector2.ZERO


## Where thrown / fired things go: straight at the locked target (any angle, not snapped to 8 ways), otherwise the
## current facing. Projectiles and jutsu should ask this, never read facing8 directly.
func aim_direction() -> Vector2:
	var d := lock_aim_dir()
	if d != Vector2.ZERO:
		return d
	return facing8.normalized() if facing8 != Vector2.ZERO else Vector2.DOWN


## R2 is held and a face button was pressed: if that slot holds a playable jutsu, the press belongs to the jutsu (it never
## also swings the sword / dodges / jumps). Returns true when the press was consumed.
func _jutsu_press(slot: String) -> bool:
	var id := String(inventory.jutsu.get(slot, ""))
	if id == "" or not bool(PlayerInventory.JUTSU.get(id, {}).get("ready", false)):
		return false
	use_jutsu(slot)
	return true


## Fire the jutsu on an R2 slot. Returns false if it could not start (no chakra, cooling down, busy).
func use_jutsu(slot: String) -> bool:
	match String(inventory.jutsu.get(slot, "")):
		"chidori":
			return _begin_chidori()
	return false


func _begin_chidori() -> bool:
	if chidori_phase != ChidoriPhase.NONE or chidori_cd > 0.0 or chakra < CHIDORI_COST or dying or _hurt_t > 0.0 or _throw_t > 0.0:
		return false
	if state != State.IDLE and state != State.MOVE and state != State.SPRINT:
		return false
	chakra -= CHIDORI_COST
	chakra_changed.emit(chakra, max_chakra)
	chidori_phase = ChidoriPhase.CHARGE
	chidori_t = 0.0
	chidori_dir = aim_direction()
	if lock_aim_dir() != Vector2.ZERO:
		facing8 = _snap8(chidori_dir)
	chidori_hits.clear()
	chidori_count += 1
	velocity = Vector2.ZERO
	if chidori_fx == null:
		chidori_fx = ChidoriFx.new()
		chidori_fx.name = "ChidoriFx"
		add_child(chidori_fx)
	chidori_fx.begin_charge(chidori_dir)
	state = State.IDLE
	visual.set_pose(facing8, false, false)
	return true


func _cancel_chidori() -> void:
	if chidori_phase == ChidoriPhase.NONE:
		return
	chidori_phase = ChidoriPhase.NONE
	chidori_cd = CHIDORI_COOLDOWN
	if chidori_fx != null:
		chidori_fx.stop()


func _tick_chidori(delta: float) -> void:
	var prev_state := state
	chidori_t += delta
	match chidori_phase:
		ChidoriPhase.CHARGE:
			velocity = Vector2.ZERO
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var lock_dir := lock_aim_dir()
			if lock_dir != Vector2.ZERO:  # locked on: the bolt tracks the target while charging
				facing = lock_dir
				facing8 = _snap8(lock_dir)
				chidori_dir = lock_dir
				chidori_fx.dir8 = chidori_dir
			elif input != Vector2.ZERO:  # aim while charging
				facing = input.normalized()
				facing8 = _snap8(facing)
				chidori_dir = facing8.normalized()
				chidori_fx.dir8 = chidori_dir
			visual.set_pose(facing8, false, false)
			if chidori_t >= CHIDORI_CHARGE_TIME:
				chidori_phase = ChidoriPhase.RUSH
				chidori_t = 0.0
				_chidori_start = global_position
				chidori_fx.begin_rush(chidori_dir)
				state = State.SPRINT
		ChidoriPhase.RUSH:
			velocity = chidori_dir * CHIDORI_RUSH_SPEED
			move_and_slide()
			visual.set_pose(facing8, true, true)
			var target := _chidori_contact()
			var blocked := get_slide_collision_count() > 0 and get_real_velocity().length() < CHIDORI_RUSH_SPEED * 0.5
			var spent := global_position.distance_to(_chidori_start) >= CHIDORI_RUSH_MAX
			if target != null:
				_chidori_burst(target.global_position, true)
			elif blocked:
				_chidori_burst(global_position + chidori_dir * 22.0, false)
			elif spent:
				_chidori_burst(global_position + chidori_dir * 18.0, false, 0.5)
		ChidoriPhase.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, friction * 2.0 * delta)
			move_and_slide()
			visual.set_pose(facing8, false, false)
			if chidori_t >= CHIDORI_RECOVER_TIME:
				chidori_phase = ChidoriPhase.NONE
				state = State.IDLE
	if state != prev_state:
		state_changed.emit(state)


## First live enemy touching the rush with a clear line to it (never through a wall), not yet struck by this rush.
func _chidori_contact() -> Node2D:
	var space := get_world_2d().direct_space_state
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or e == self or chidori_hits.has(e) or not e.has_method("take_damage"):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		var d: Vector2 = (e as Node2D).global_position - global_position
		if Vector2(d.x, d.y * 1.6).length() > CHIDORI_CONTACT:
			continue
		if _wall_between(space, global_position, (e as Node2D).global_position, e):
			continue
		return e as Node2D
	return null


func _wall_between(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2, ignore: Node) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a + Vector2(0, -14), b + Vector2(0, -14))
	var ex: Array[RID] = [get_rid()]
	if ignore is CollisionObject2D:
		ex.append((ignore as CollisionObject2D).get_rid())
	q.exclude = ex
	return not space.intersect_ray(q).is_empty()


## The rush ends here: burst, damage (only when it hit an enemy), a short hit-stop, then a brief recovery.
func _chidori_burst(at: Vector2, hit_enemy: bool, scale_k := 1.0) -> void:
	chidori_fx.stop()
	chidori_phase = ChidoriPhase.RECOVER
	chidori_t = 0.0
	chidori_cd = CHIDORI_COOLDOWN
	velocity = -chidori_dir * 60.0
	ChidoriImpact.spawn(get_parent(), at, chidori_dir, scale_k)
	if not hit_enemy:
		return
	var space := get_world_2d().direct_space_state
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or e == self or chidori_hits.has(e) or not e.has_method("take_damage"):
			continue
		var d: Vector2 = (e as Node2D).global_position - at
		var primary := Vector2(d.x, d.y * 1.6).length() <= CHIDORI_CONTACT + 8.0
		var splash := Vector2(d.x, d.y * 2.0).length() <= CHIDORI_SPLASH_RADIUS
		if not (primary or splash) or _wall_between(space, at, (e as Node2D).global_position, e):
			continue
		chidori_hits.append(e)
		var away := d.normalized() if d.length() > 1.0 else chidori_dir
		e.call("take_damage", CHIDORI_DAMAGE if primary else CHIDORI_SPLASH_DAMAGE, away, CHIDORI_KNOCKBACK if primary else CHIDORI_KNOCKBACK * 0.5, CHIDORI_HITSTOP_MS)
	_hitstop_timer = maxf(_hitstop_timer, 0.07)


## Start a forward kunai throw (costs one kunai). Only from plain locomotion/idle, one at a time.
func _begin_throw(item := "kunai") -> bool:
	if _throw_t > 0.0 or inventory.count_of(item) <= 0:
		return false
	if state != State.IDLE and state != State.MOVE and state != State.SPRINT:
		return false
	inventory.consume(item)
	_throw_item = item
	_throw_t = THROW_TIME
	_throw_released = false
	_throw_dir = aim_direction()
	facing8 = _snap8(_throw_dir)
	return true


func _tick_throw(delta: float) -> void:
	if _throw_t <= 0.0:
		return
	_throw_t = maxf(_throw_t - delta, 0.0)
	var progress := 1.0 - _throw_t / THROW_TIME
	if not _throw_released and progress >= THROW_RELEASE:
		_throw_released = true
		if _throw_item == "smoke_tag_bomb":
			SmokeTagBomb.spawn_smoke(get_parent(), global_position + _throw_dir * 18.0 + THROW_HAND, _throw_dir, self)
		elif _throw_item in ["paper_tag", "tag_bomb"]:
			tags_thrown_count += 1
			PaperTagBomb.spawn(get_parent(), global_position + _throw_dir * 18.0 + THROW_HAND, _throw_dir, self, "tag_bomb" if _throw_item == "tag_bomb" else "")
		else:
			kunai_thrown_count += 1
			PlayerKunai.spawn(get_parent(), global_position + _throw_dir * 18.0 + THROW_HAND, _throw_dir, self)


## No dedicated throw art exists yet: use the "throw" animation if a sprite set ever ships one, otherwise borrow the
## first half of the light attack (arm drawn back, then forward) so the throw still reads as a throw.
func _play_throw_visual() -> void:
	var progress := clampf(1.0 - _throw_t / THROW_TIME, 0.0, 1.0)
	if visual.has_action("throw"):
		visual.play_action_progress("throw", _snap8(_throw_dir), progress)
	else:
		visual.play_action_progress("light1", _snap8(_throw_dir), progress * 0.5)


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


## Picked-up ryo (a RyoPouch dropped by a downed fighter).
func gain_ryo(amount: int) -> void:
	if amount > 0:
		ryo += amount
		ryo_changed.emit(ryo)


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
		var chain_window := _attack_def.combo_window_for(_hit_confirmed)
		e.combo = chain_window > 0.0 and elapsed <= chain_window
		var cancel_from := _attack_def.dodge_cancel_from_for(_hit_confirmed)
		e.dodge_cancel = state != State.AIR_ATTACK and cancel_from >= 0.0 and elapsed >= cancel_from
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
		"hit_confirmed": _hit_confirmed,
		"cancel": cancel_eligibility(),
	}


## Snap a direction to one of 8 unit-ish headings (diagonals normalized).
static func _snap8(dir: Vector2) -> Vector2:
	var idx := int(roundf(dir.angle() / (PI / 4.0)))
	return Vector2.from_angle(idx * (PI / 4.0)).snapped(Vector2(0.01, 0.01))
