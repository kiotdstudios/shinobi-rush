class_name Bandit
extends CharacterBody2D
## Level 1 "robber" Bandit (Level 1 Bandit robber order).
##
## Behaviour loop: PATROL -> NOTICE -> APPROACH -> THREATEN -> ATTACK -> REPOSITION / RETREAT (rare
## double backward Body Flicker) -> SEARCH -> RETURN -> PATROL. Every "feel" number comes from the
## EnemyIntelligence profile (`intelligence_level`), so a smarter Level 2 is a new profile row.
##
## Fairness rules baked in: it only acquires with range + facing cone + an unobstructed line of sight
## (walls block detection), it paths AROUND walls via ArenaNav, every swing has a visible windup, aim
## freezes before the active frames, and hits need line of sight at the moment of impact.
##
## BanditVisual binds Codex's red-scarf idle/run/sprint art. There is no dedicated attack/alert art
## yet: the telegraphs are drawn as code overlays (see BanditVisual) and art is requested in
## orders/Codex/2026-10-21-bandit-level1-action-art.md.

enum State { IDLE, APPROACH, HIT_REACT, DEAD, EVADE, PATROL, NOTICE, THREATEN, ATTACK, REPOSITION, RETREAT, SEARCH, RETURN }
const THROW_RELEASE_AT := 0.7  ## fraction of the throw animation at which the kunai leaves the hand
enum AtkPhase { NONE, WINDUP1, ACTIVE1, GAP, WINDUP2, ACTIVE2, RECOVERY, THROW_WINDUP, THROW_RECOVERY, THROW_GAP }
enum RetreatPhase { NONE, TELEGRAPH, HOP1, PAUSE, HOP2, RECOVER }

signal intent_changed(state_name: String, reason: String)
signal defeated  ## hp reached 0 (the arena spawns a replacement Bandit a few seconds later)

const SKIN := Color("#8a4a3a")
const CLOTH := Color("#4a3a2a")
const HIT_FLASH := Color(1.0, 0.25, 0.2, 0.9)
const KNOCKBACK_ANIM_SPEED := 200.0  ## hits at least this hard play the 12-frame knockback clip
const HIT_REACT_CLIP := 0.333
const KNOCKBACK_CLIP := 0.5
const TAUNT_TEXT := "Hand over your ryo!"
const TAUNT_TIME := 2.4
const EYE_OFFSET := Vector2(0, -13.5)  ## sight/attack rays run at collider height, like the walls' footprints
const LOG_MAX := 40
## States in which this Bandit is actively engaged with `locked_target` (owner 2026-10-22: "enemies
## should auto engage lock onto players"). Deliberately separate from the narrower `chasing` list in
## `_update_perception()` (which only widens the sight check) -- this one drives `is_locked_on()` and
## is reused by nothing else, so changing it cannot shift unrelated sight/cone behaviour.
const ENGAGED_STATES: Array = [State.NOTICE, State.APPROACH, State.THREATEN, State.ATTACK, State.REPOSITION, State.RETREAT, State.SEARCH, State.EVADE, State.HIT_REACT]
@export var intelligence_level: int = 1
## Sense stat (owner: "the higher the stat the bigger the circle") -- NOT `intelligence_level` above,
## which selects the AI tuning profile. This one only widens the omnidirectional proximity-detection
## circle used while `is_sprinting` (its own "naruto running"), see ProximitySense/sense_radius().
## PROVISIONAL PROTOTYPE value, not balance.
@export var intelligence: int = 5
@export var max_hp: float = 60.0
@export var detect_radius: float = 420.0  ## legacy: kept for tuning panels; sight now comes from the profile
@export var combat_distance: float = 130.0  ## approach stops at roughly this range from the player
@export var move_speed: float = 320.0
@export var chase_speed: float = 470.0
@export var evade_speed: float = 640.0
@export var evade_duration: float = 0.20
@export var evade_cooldown: float = 1.25
@export var hit_react_duration: float = 0.22
@export var hit_flash_duration: float = 0.12
## Patrol loop in world px. Empty = guard `home` and look around.
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var debug_log: bool = false
## "Naruto running" woods patrol (owner 2026-10-22): short breather between waypoint legs while on an
## authored patrol loop, replacing the old long `profile.patrol_wait` stand-and-look-around pause so the
## Level 1 robber reads as continuously running the woods, not strolling. Only used when `patrol_points`
## is non-empty; the empty-points "stand guard and look around" fallback is unchanged (several isolated
## geometry/combat tests deliberately freeze the Bandit in place that way).
@export var roam_pause: float = 0.4
## Brief grace after giving up a chase (leash exceeded, or SEARCH timed out) before free-roaming.
## Owner 2026-10-22: "I want the logic for all enemies to stay in their new area" -- RETURN settles the
## Bandit exactly where it gave up (see `home` snapshot in `_enter`). Owner follow-up 2026-10-22 (same
## day): "I do not want there to be a home position; bandit's new home is the last seen location and he
## continues his search" -- once a Bandit has EVER given up a chase (`_ever_disengaged`), it never walks
## back to its original authored `patrol_points` loop again; `_tick_patrol` instead free-roams forever
## from wherever it is (see `_tick_roam`/`_pick_roam_target`), still sprinting and still sensing/looking
## for players. The first patrol of a Bandit's life (before it has ever disengaged) still walks the
## authored loop, preserving the level-designed look of an undisturbed guard.
@export var return_settle_time: float = 0.4
## Radius (world px) `_pick_roam_target` searches within once free-roaming (see `return_settle_time`).
@export var roam_radius: float = 260.0
## Owner 2026-10-22: "bandit lvl 1 is looking for players with under 30 ryo to try to steal it upon
## defeating players." Gates the STEAL action only (see `_try_hit`/`is_worth_robbing`), not detection or
## combat -- every player is still chased, threatened and fought the same regardless of ryo. PROVISIONAL
## PROTOTYPE value, not balance.
@export var ryo_steal_threshold: int = 30

var is_sprinting := false
var evade_count := 0
var flicker_count := 0
var flicker_hopping := false
var _evade_timer := 0.0
var _evade_cooldown := 0.0
var _evade_side := 1.0

var state: State = State.PATROL
var hp: float = max_hp
## Status stats (HUD parity with the player). Substitution is charge-based with a recharge timer and costs no chakra, exactly like the player; the chakra pool is currently display-only.
var max_chakra: float = 100.0
var chakra: float = 100.0
var is_charging_chakra := false  ## true while he is standing still charging chakra (blue aura)
var _chakra_wanted := false  ## set when a move could not be paid for: he charges as soon as it is safe
var sub_use_age: Array[float] = []  ## seconds since each substitution pip was spent (-1 = idle); drives the log wiggle + smoke on his bar
var max_substitutions: int = 2
var substitutions: int = 2
var facing8: Vector2 = Vector2.DOWN
var profile: Dictionary = {}
var nav: ArenaNav = null
var home: Vector2 = Vector2.ZERO
## Owner 2026-10-22 (second follow-up, same day): "bandit now moves to another ... home ... instead of
## that being his now home area" -- the chase leash (see _tick_approach) must be measured from where
## THIS chase started, not the stale `home` left over from a PREVIOUS disengage. Using `home` meant a
## Bandit that had already roamed away from its last give-up point, then started a brand new chase,
## would hit the leash almost immediately (it was already most of the way to `chase_leash` from the old
## point before the chase even began) and give up near the OLD area again, never actually following the
## player deep into wherever it ran this time. Set fresh on every genuinely new engagement (see `_enter`'s
## State.APPROACH case); `home` is untouched by this and still only updated on RETURN.
var _chase_origin: Vector2 = Vector2.ZERO
var sees_player := false
var senses_player := false  ## proximity "power level" sense (ProximitySense); distance-only, no cone/LOS
var locked_target: Node2D = null  ## non-null while actively engaged (see ENGAGED_STATES/is_locked_on())
var _ever_disengaged := false  ## true once RETURN has ever been entered; see roam_radius doc comment
var stolen_ryo: int = 0  ## running tally of ryo actually stolen (see _try_hit/is_worth_robbing)
var player_hits_landed := 0
var swings_thrown := 0
var overcommits := 0
var stuck_events := 0
var path_requests := 0
var turn_pauses := 0
var taunt_timer := 0.0
var engagement_count := 0
var atk_phase: AtkPhase = AtkPhase.NONE
var retreat_phase: RetreatPhase = RetreatPhase.NONE
var intent_log: Array[String] = []
var last_seen: Vector2 = Vector2.ZERO
var clock := 0.0

var _hit_react_timer: float = 0.0
var react_kind: String = "hit_react"  ## hit_react | knockback | death, read by BanditVisual
var react_duration: float = 0.333
var _death_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _state_time := 0.0
var _patrol_idx := 0
var _roam_target: Vector2 = Vector2.ZERO
var _has_roam_target := false
var _wait_timer := 0.0
var _return_settle_timer := 0.0  ## seconds left settling into the new home on RETURN (see return_settle_time)
var _look_timer := 0.0
var _look_step := 0
var _look_base := Vector2.DOWN
var _notice_timer := 0.0
var _notice_blind := 0.0
var _resume_state: State = State.PATROL
var _has_lost_player := false
var _lose_timer := 0.0
var _threaten_timer := 0.0
var _atk_cooldown := 0.0
var _throw_cooldown := 2.0  ## seconds until the next kunai throw is allowed
var kunai_thrown := 0  ## kunai released this life (read by tests / telemetry)
var _burst_left := 0  ## kunai still to release in the current throw combo
var _burst_index := 0
var _sub_cooldowns: Array[float] = []  ## seconds until each spent substitution charge returns
var _sub_gap := 0.0  ## lockout between two swaps
var _sub_invuln := 0.0  ## grace after a swap
var substitution_count := 0  ## swaps used this life (tests / telemetry)
static var substitution_enabled := true  ## master switch (the test suite turns it off so random swaps cannot flake unrelated tests)
signal substituted(old_pos: Vector2, new_pos: Vector2)
var _atk_timer := 0.0
var _atk_dir := Vector2.DOWN
var _atk_hit_done := [false, false]
var _overcommit := false
var _retreat_timer := 0.0
var _retreat_dir := Vector2.LEFT
var _retreat_hop_velocity := Vector2.ZERO
var _reposition_timer := 0.0
var _reposition_dir := Vector2.LEFT
var _search_arrived := false
var _search_timer := 0.0
var _turn_pause := 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_idx := 0
var _path_goal := Vector2.ZERO
var _repath_timer := 0.0
var _stuck_timer := 0.0
var _stuck_ref := Vector2.ZERO
var _moving_intent := false

## Logical height above the ground on climbable terrain (see ShrineElevation): the figure is drawn this much higher.
var elevation: float = 0.0

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	set_intelligence_level(intelligence_level)
	_rng.randomize()
	var shape := RectangleShape2D.new()
	shape.size = WorldScale.FOOTPRINT
	var col := $CollisionShape2D as CollisionShape2D
	col.shape = shape
	col.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_mask |= ShrineElevation.EDGE_LAYER  # stair sides and cliff rims hold every climber, not just the player
	home = global_position
	last_seen = home
	_stuck_ref = global_position
	_look_base = facing8
	var arena := get_parent()
	if arena is TrainingArena:
		nav = (arena as TrainingArena).nav


func set_intelligence_level(level: int) -> void:
	intelligence_level = level
	profile = EnemyIntelligence.profile(level)


func seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func set_home(p: Vector2) -> void:
	home = p


# ---------------------------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer - delta, 0.0)
		visual.queue_redraw()
		return  # local hitstop only: this entity's movement pauses, global timers/input elsewhere are untouched

	clock += delta
	ShrineElevation.update_actor(self, delta)
	visual.position.y = -elevation
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	_evade_cooldown = maxf(_evade_cooldown - delta, 0.0)
	_atk_cooldown = maxf(_atk_cooldown - delta, 0.0)
	_throw_cooldown = maxf(_throw_cooldown - delta, 0.0)
	_tick_substitution(delta)
	taunt_timer = maxf(taunt_timer - delta, 0.0)
	_turn_pause = maxf(_turn_pause - delta, 0.0)
	_state_time += delta

	if state == State.DEAD:
		_death_time += delta
		if velocity.length_squared() > 1.0:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 5.0 * delta)
			move_and_slide()
		return
	if state == State.EVADE:
		var remaining := minf(delta, _evade_timer)
		var burst_velocity := velocity
		velocity *= remaining / maxf(delta, 0.00001)
		move_and_slide()
		velocity = burst_velocity
		_evade_timer -= delta
		if _evade_timer <= 0.0 or get_slide_collision_count() > 0:
			_enter(State.APPROACH, "evade done")
			velocity = Vector2.ZERO
		return

	if state == State.HIT_REACT:
		_hit_react_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 4.0 * delta)
		move_and_slide()
		if _hit_react_timer <= 0.0:
			if _player != null:
				last_seen = _player.global_position
				_lose_timer = 0.0
				_enter(State.APPROACH, "struck: alerted")
			else:
				_enter(State.PATROL, "struck, no target")
		visual.queue_redraw()
		return

	_find_player()
	_update_perception()

	if _tick_chakra_charge(delta):
		velocity = Vector2.ZERO
		move_and_slide()
		visual.queue_redraw()
		return

	match state:
		State.IDLE, State.PATROL:
			_tick_patrol(delta)
		State.NOTICE:
			_tick_notice(delta)
		State.APPROACH:
			_tick_approach(delta)
		State.THREATEN:
			_tick_threaten(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.REPOSITION:
			_tick_reposition(delta)
		State.RETREAT:
			_tick_retreat(delta)
		State.SEARCH:
			_tick_search(delta)
		State.RETURN:
			_tick_return(delta)

	if state == State.EVADE:
		move_and_slide()
		return
	move_and_slide()
	_check_stuck(delta)
	visual.queue_redraw()


# ---------------------------------------------------------------------------------- perception
func _update_perception() -> void:
	if _player == null or not is_instance_valid(_player):
		sees_player = false
		senses_player = false
		return
	var chasing := state in [State.NOTICE, State.APPROACH, State.THREATEN, State.ATTACK, State.REPOSITION, State.RETREAT]
	sees_player = can_see(_player.global_position, not chasing)
	if sees_player:
		last_seen = _player.global_position
	# Proximity "power level" sense while naruto-running (is_sprinting): distance-only, no facing cone,
	# no line of sight -- a sprinting body is felt/loud, not just seen (see ProximitySense). Owner:
	# "when naruto running and near enemy ... player will auto detect and pull their kunai out" --
	# the symmetric case for the Bandit: it auto-notices a nearby player even outside its sight cone.
	senses_player = is_sprinting and global_position.distance_to(_player.global_position) <= sense_radius()
	# Owner 2026-10-22: "enemies should auto engage lock onto players" -- the sense is a felt power-level
	# read, not a glimpse that needs confirming, so it skips the sight path's NOTICE suspicion delay
	# entirely and commits straight to APPROACH (locked_target is set in _enter's State.APPROACH case).
	if senses_player and state in [State.PATROL, State.IDLE, State.SEARCH, State.RETURN]:
		last_seen = _player.global_position
		_enter(State.APPROACH, "sensed: proximity -> instant lock-on (intelligence %d)" % intelligence)


## Range + (optionally) facing cone + clear line of sight. Walls block detection exactly like they
## block movement: the ray runs against the same colliders.
func can_see(target: Vector2, use_cone: bool) -> bool:
	var to := target - global_position
	var d := to.length()
	var reach: float = float(profile.sight_range) * (1.0 if use_cone else 1.2)
	if d > reach:
		return false
	if use_cone and d > float(profile.close_sense):
		var half := deg_to_rad(float(profile.fov_deg) * 0.5)
		if absf(facing8.angle_to(to)) > half:
			return false
	return line_clear_to(target)


## True if no collider (wall/block/bounds) lies between this body and `target` at collider height.
func line_clear_to(target: Vector2) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + EYE_OFFSET, target + EYE_OFFSET)
	var excluded: Array[RID] = [get_rid()]
	if _player is CollisionObject2D:
		excluded.append((_player as CollisionObject2D).get_rid())
	q.exclude = excluded
	return space.intersect_ray(q).is_empty()


## World-px radius of the proximity "power level" sense (see `senses_player`/`_update_perception`).
func sense_radius() -> float:
	return ProximitySense.radius_for(intelligence)


## True while actively engaged with `locked_target` (owner: "enemies should auto engage lock onto
## players"). See ENGAGED_STATES; cleared on PATROL/RETURN entry (full disengage/settle).
func is_locked_on() -> bool:
	return locked_target != null and state in ENGAGED_STATES


## Owner 2026-10-22: "bandit lvl 1 is looking for players with under 30 ryo to try to steal it upon
## defeating players." `p` without a readable `ryo` property (e.g. a bare test stand-in) is always
## worth robbing -- this never blocks detection/combat (see ryo_steal_threshold's doc comment), it only
## gates whether `_try_hit` actually steals anything once a hit lands.
func is_worth_robbing(p: Node) -> bool:
	if p == null:
		return false
	var r = p.get("ryo")
	return r == null or int(r) < ryo_steal_threshold


## Steals everything `p` is carrying (capped at ryo_steal_threshold worth is not implied -- "steal it"
## means the whole stash) via `p.lose_ryo()`. No-op if `p` has no such method (bare test stand-ins).
func _steal_ryo(p: Node) -> void:
	if p == null or not p.has_method("lose_ryo"):
		return
	var taken: int = p.call("lose_ryo", int(p.get("ryo")))
	if taken > 0:
		stolen_ryo += taken
		_log("stole %d ryo" % taken)


# ---------------------------------------------------------------------------------- states
func _enter(next: State, reason: String = "") -> void:
	if next == state:
		return
	var prev := state
	state = next
	_state_time = 0.0
	is_sprinting = false
	_path = PackedVector2Array()
	_repath_timer = 0.0
	match next:
		State.NOTICE:
			_throw_cooldown = maxf(_throw_cooldown, float(profile.get("throw_first_delay", 2.0)))  # no instant kunai on first sight
			_resume_state = prev if prev in [State.PATROL, State.RETURN, State.SEARCH, State.IDLE] else State.PATROL
			_notice_timer = 0.0
			_notice_blind = 0.0
		State.APPROACH:
			_lose_timer = 0.0
			locked_target = _player  ## owner: "enemies should auto engage lock onto players"
			if prev in [State.PATROL, State.NOTICE, State.IDLE, State.SEARCH, State.RETURN]:
				engagement_count += 1
				_chase_origin = global_position  ## fresh engagement: leash measures from HERE, not stale `home`
		State.THREATEN:
			_threaten_timer = float(profile.threaten_time) if prev == State.APPROACH else float(profile.rethreaten_time)
			if _first_contact_pending:
				# Robber line on the first close encounter of each engagement: a drawn label, never a pause.
				taunt_timer = TAUNT_TIME
				_first_contact_pending = false
				_log("says: " + TAUNT_TEXT)
		State.SEARCH:
			_search_arrived = false
			_search_timer = float(profile.search_duration)
			_has_lost_player = true
		State.RETURN:
			# Owner 2026-10-22: "I want the logic for all enemies to stay in their new area" -- giving up
			# a chase (leash exceeded, or SEARCH timed out) adopts wherever the Bandit is RIGHT NOW as its
			# new home, instead of marching back to the original spawn. _tick_return only settles in place.
			# Owner follow-up, same day: "I do not want there to be a home position" -- _ever_disengaged
			# makes this permanent: the PATROL that follows free-roams from here on (see _tick_roam), it
			# never walks back to the original authored patrol_points loop again.
			home = global_position
			_ever_disengaged = true
			_return_settle_timer = return_settle_time
			locked_target = null
			_look_base = facing8
			_look_timer = 0.0
			_look_step = 0
		State.PATROL:
			_wait_timer = 0.4
			_has_lost_player = false
			_first_contact_pending = true
			_look_base = facing8
			locked_target = null
	_log("%s>%s %s" % [State.keys()[prev], State.keys()[next], reason])
	intent_changed.emit(State.keys()[next], reason)


var _first_contact_pending := true


func _log(msg: String) -> void:
	var line := "%.2f L%d %s" % [clock, int(profile.get("level", intelligence_level)), msg]
	intent_log.append(line)
	if intent_log.size() > LOG_MAX:
		intent_log.pop_front()
	if debug_log:
		print("[bandit] ", line)


func _tick_patrol(delta: float) -> void:
	if sees_player:
		_enter(State.NOTICE, "spotted player at %d px" % int(global_position.distance_to(_player.global_position)))
		return
	if patrol_points.is_empty():
		# Isolated-test freeze convenience (no authored waypoints): stand guard and look around. The
		# real deployed Level 1 robber always has patrol_points set (see training_arena.gd) and takes
		# the "naruto running" branch below instead.
		velocity = Vector2.ZERO
		is_sprinting = false
		if _wait_timer > 0.0:
			_wait_timer -= delta
			_look_around(delta)
			if _wait_timer <= 0.0:
				_look_step = 0
			return
		_wait_timer = float(profile.patrol_wait)
		return
	# Owner follow-up 2026-10-22: "I do not want there to be a home position; bandit's new home is the
	# last seen location and he continues his search." Once the Bandit has ever given up a chase, it
	# never walks back to this authored loop again -- it free-roams instead (see _tick_roam).
	if _ever_disengaged:
		_tick_roam(delta)
		return
	# Owner 2026-10-22: "bandits are in the woods running around looking for players (naruto running)" --
	# sprints between its authored waypoints (is_sprinting=true also activates the proximity sense, see
	# _update_perception) with only a short breather at each stop, instead of a slow patrol-speed walk.
	if _wait_timer > 0.0:
		velocity = Vector2.ZERO
		is_sprinting = false
		_wait_timer -= delta
		_look_around(delta)
		if _wait_timer <= 0.0:
			_look_step = 0
		return
	var target := patrol_points[_patrol_idx % patrol_points.size()]
	is_sprinting = true
	if _follow(target, chase_speed, delta, 26.0):
		is_sprinting = false
		_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		_wait_timer = roam_pause
		_look_base = facing8
		_look_timer = 0.0


## Owner follow-up 2026-10-22: "I do not want there to be a home position; bandit's new home is the
## last seen location and he continues his search to find people to attack." Entered permanently once
## `_ever_disengaged` is true (see `_enter`'s State.RETURN case) -- the Bandit never walks back to its
## original authored `patrol_points` loop again; it free-roams from wherever it currently is, forever,
## still sprinting (keeps its own proximity sense active, see `_update_perception`) and still looking
## for players to re-engage.
func _tick_roam(delta: float) -> void:
	if _wait_timer > 0.0:
		velocity = Vector2.ZERO
		is_sprinting = false
		_wait_timer -= delta
		_look_around(delta)
		if _wait_timer <= 0.0:
			_look_step = 0
		return
	if not _has_roam_target:
		_pick_roam_target()
	is_sprinting = true
	if _follow(_roam_target, chase_speed, delta, 26.0):
		is_sprinting = false
		_has_roam_target = false
		_wait_timer = roam_pause
		_look_base = facing8
		_look_timer = 0.0


## Picks a new free-roam destination within `roam_radius` of the Bandit's CURRENT position (not any
## fixed point). Tries a few random directions/distances and keeps the first one `nav` (if present)
## reports walkable; falls back to standing pat for this cycle if none land (dense geometry nearby).
func _pick_roam_target() -> void:
	var origin := global_position
	for i in 6:
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(roam_radius * 0.4, roam_radius)
		var candidate := origin + Vector2.from_angle(ang) * dist
		if nav == null or nav.is_walkable(candidate):
			_roam_target = candidate
			_has_roam_target = true
			return
	_roam_target = origin
	_has_roam_target = true


func _tick_notice(delta: float) -> void:
	velocity = Vector2.ZERO
	if _player == null:
		_enter(_resume_state, "target gone")
		return
	if sees_player:
		_notice_blind = 0.0
		_face(_player.global_position - global_position)
		_notice_timer += delta
		var need: float = float(profile.notice_delay) * (1.6 if _has_lost_player else 1.0)
		if _notice_timer >= need:
			_enter(State.APPROACH, "noticed")
	else:
		_notice_blind += delta
		_face(last_seen - global_position)
		if _notice_blind > 0.5:
			_enter(_resume_state, "lost glimpse")


func _tick_approach(delta: float) -> void:
	if _player == null:
		_enter(State.SEARCH, "no player")
		return
	if sees_player:
		_lose_timer = 0.0
	else:
		_lose_timer += delta
		if _lose_timer > float(profile.lose_sight_time):
			_enter(State.SEARCH, "lost sight")
			return
	# The leash only gives up a chase the Bandit has lost sight of; while the player is in view it keeps
	# coming (owner 2026-10-22: "he stops the chase though I'm in his vision"). When it does need to
	# fire, it measures from where THIS chase started (_chase_origin), never a stale `home` left by a
	# PREVIOUS disengage the Bandit has since roamed away from (owner 2026-10-22, second correction:
	# "he goes back to the last home area instead of that being his now home area").
	if not sees_player and _chase_origin.distance_to(global_position) > float(profile.chase_leash):
		_enter(State.RETURN, "chase leash")
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if sees_player and _should_evade(to_player) and _begin_evade(to_player):
		_evade_timer -= delta
		return
	if _can_throw(dist):
		_begin_throw()
		return
	if sees_player and dist <= combat_distance:
		_enter(State.THREATEN, "in range")
		velocity = Vector2.ZERO
		_face(to_player)
		return
	var goal := _player.global_position if sees_player else last_seen
	if dist > 250.0:
		is_sprinting = true
	elif dist < 185.0:
		is_sprinting = false
	var speed := chase_speed if is_sprinting else move_speed
	if not sees_player:
		is_sprinting = false
		speed = move_speed
	if _follow(goal, speed, delta, 20.0, false) and not sees_player:
		_enter(State.SEARCH, "reached last seen")


func _tick_threaten(delta: float) -> void:
	if _player == null:
		_enter(State.SEARCH, "no player")
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	velocity = Vector2.ZERO
	_face(to_player)
	if sees_player:
		_lose_timer = 0.0
	else:
		_lose_timer += delta
		if _lose_timer > float(profile.lose_sight_time):
			_enter(State.SEARCH, "lost sight")
			return
	if sees_player and _should_evade(to_player) and _begin_evade(to_player):
		_evade_timer -= delta
		return
	if dist > combat_distance + 40.0:
		_enter(State.APPROACH, "player backed off")
		return
	_threaten_timer = maxf(_threaten_timer - delta, 0.0)
	if sees_player and _threaten_timer <= 0.0 and _atk_cooldown <= 0.0 and dist <= float(profile.attack_reach):
		_begin_attack()
	elif dist > float(profile.attack_reach) and _can_throw(dist):
		_begin_throw()


## Ranged option: a kunai throw at mid range with a clear line. Windup tracks the player for the first
## half, then the aim freezes (a sidestep / dodge after the freeze beats it), then the kunai leaves the
## hand on the release frame and the Bandit recovers.
func _can_throw(dist: float) -> bool:
	return (
		sees_player
		and _player != null
		and _throw_cooldown <= 0.0
		and _atk_cooldown <= 0.0
		and dist >= float(profile.get("throw_min", 190.0))
		and dist <= float(profile.get("throw_range", 420.0))
		and line_clear_to(_player.global_position)
	)


func _begin_throw() -> void:
	_enter(State.ATTACK, "kunai")
	atk_phase = AtkPhase.THROW_WINDUP
	_burst_left = 0
	_burst_index = 0
	_atk_timer = float(profile.get("throw_windup", 0.42))
	_atk_dir = (_player.global_position - global_position).normalized()
	velocity = Vector2.ZERO
	facing8 = WorldScale.snap8(_atk_dir)


func _tick_throw(delta: float) -> void:
	_atk_timer -= delta
	velocity = Vector2.ZERO
	if atk_phase == AtkPhase.THROW_WINDUP:
		var total: float = float(profile.get("throw_windup", 0.42))
		if _atk_timer >= total * 0.5 and _player != null:
			_atk_dir = (_player.global_position - global_position).normalized()
		facing8 = WorldScale.snap8(_atk_dir)
		if _atk_timer <= 0.0:
			_burst_left = maxi(int(profile.get("throw_burst_count", 1)), 1)
			_burst_index = 0
			_release_kunai()
			_after_release()
	elif atk_phase == AtkPhase.THROW_GAP:
		facing8 = WorldScale.snap8(_atk_dir)
		if _atk_timer <= 0.0:
			_release_kunai()
			_after_release()
	elif _atk_timer <= 0.0:
		atk_phase = AtkPhase.NONE
		_throw_cooldown = float(profile.get("throw_cooldown", 3.5))
		_atk_cooldown = maxf(_atk_cooldown, 0.8)
		_enter(State.APPROACH, "after throw")


## After each kunai: more to throw -> short gap, otherwise the recovery.
func _after_release() -> void:
	if _burst_left > 0:
		atk_phase = AtkPhase.THROW_GAP
		_atk_timer = float(profile.get("throw_burst_gap", 0.14))
	else:
		atk_phase = AtkPhase.THROW_RECOVERY
		_atk_timer = float(profile.get("throw_recovery", 0.3))


func _release_kunai() -> void:
	kunai_thrown += 1
	var n := maxi(int(profile.get("throw_burst_count", 1)), 1)
	var spread := deg_to_rad(float(profile.get("throw_spread_deg", 9.0)))
	var dir := _atk_dir.rotated((float(_burst_index) - float(n - 1) * 0.5) * spread)
	_burst_index += 1
	_burst_left = maxi(_burst_left - 1, 0)
	_log("kunai thrown %d/%d" % [_burst_index, n])
	BanditKunai.spawn(get_parent(), global_position + dir * 18.0, dir, self, _player, float(profile.get("throw_damage", 6.0)), float(profile.get("throw_speed", 520.0)))


## Pay for a chakra move. Returns false (and flags that he wants to charge) when the pool is short. Nothing uses it yet; substitution is free.
func spend_chakra(amount: float) -> bool:
	if chakra < amount:
		_chakra_wanted = true
		return false
	chakra -= amount
	if chakra < float(profile.get("chakra_charge_low", 0.0)) * max_chakra:
		_chakra_wanted = true
	return true


## Low pool, or a move he could not afford: he should charge.
func needs_chakra_charge() -> bool:
	if state == State.DEAD or max_chakra <= 0.0:
		return false
	return _chakra_wanted or chakra < float(profile.get("chakra_charge_low", 0.0)) * max_chakra


## Ninja chakra charge: when low (or a move was unaffordable) and the player is not on top of him he plants his feet and
## charges. Returns true while charging (the caller then skips normal behaviour). Hits, a close player or a full pool end it.
func _tick_chakra_charge(delta: float) -> bool:
	var charge_rate := float(profile.get("chakra_charge_rate", 0.0))
	if charge_rate <= 0.0:
		is_charging_chakra = false
		return false
	var full := float(profile.get("chakra_charge_full", 0.9)) * max_chakra
	if is_charging_chakra:
		if chakra >= full or not _chakra_safe() or state in [State.HIT_REACT, State.DEAD, State.EVADE]:
			is_charging_chakra = false
			_chakra_wanted = false
			_log("chakra charge done" if chakra >= full else "chakra charge interrupted")
			return false
		chakra = minf(chakra + charge_rate * delta, max_chakra)
		return true
	if needs_chakra_charge() and chakra < full and _chakra_safe() and state not in [State.HIT_REACT, State.DEAD, State.EVADE, State.ATTACK] and atk_phase == AtkPhase.NONE and not flicker_hopping:
		is_charging_chakra = true
		_log("charging chakra (%d/%d)" % [int(chakra), int(max_chakra)])
		return true
	if chakra >= full:
		_chakra_wanted = false
	return false


func _chakra_safe() -> bool:
	if _player == null or not is_instance_valid(_player):
		return true
	return global_position.distance_to(_player.global_position) > float(profile.get("chakra_charge_safe_dist", 220.0))


func _tick_substitution(delta: float) -> void:
	for i in sub_use_age.size():
		if sub_use_age[i] >= 0.0:
			sub_use_age[i] += delta
			if sub_use_age[i] > LogPip.DURATION:
				sub_use_age[i] = -1.0
	_sub_gap = maxf(_sub_gap - delta, 0.0)
	_sub_invuln = maxf(_sub_invuln - delta, 0.0)
	if state != State.DEAD:
		chakra = minf(chakra + float(profile.get("chakra_regen", 0.0)) * delta, max_chakra)
	for i in range(_sub_cooldowns.size() - 1, -1, -1):
		_sub_cooldowns[i] -= delta
		if _sub_cooldowns[i] <= 0.0:
			_sub_cooldowns.remove_at(i)
			substitutions = mini(substitutions + 1, max_substitutions)


## True when he is able to swap right now (a free charge and lockout; like the player, a swap costs NO chakra), ignoring the dice.
func can_substitute() -> bool:
	return (
		substitution_enabled
		and state != State.DEAD
		and _player != null
		and substitutions > 0
		and _sub_gap <= 0.0
	)


## Called from take_damage: swallow the hit with a log swap and reappear behind the player.
func _try_substitution() -> bool:
	if not can_substitute():
		return false
	if _rng.randf() >= float(profile.get("sub_chance", 0.0)):
		return false
	var old := global_position
	var dest := _substitution_destination()
	substitutions -= 1
	substitution_count += 1
	while sub_use_age.size() < max_substitutions:
		sub_use_age.append(-1.0)
	if substitutions >= 0 and substitutions < sub_use_age.size():
		sub_use_age[substitutions] = 0.0
	_sub_cooldowns.append(float(profile.get("sub_recharge", 15.0)))
	_sub_gap = float(profile.get("sub_min_gap", 1.0))
	_sub_invuln = float(profile.get("sub_invuln", 0.5))
	global_position = dest
	velocity = Vector2.ZERO
	atk_phase = AtkPhase.NONE
	retreat_phase = RetreatPhase.NONE
	flicker_hopping = false
	_burst_left = 0
	_log("substitution jutsu (%d left)" % substitutions)
	SubstitutionFx.spawn(get_parent(), old, dest)
	substituted.emit(old, dest)
	# Counter-position: he is now behind the player and re-threatens straight away.
	_atk_cooldown = 0.0
	_enter(State.THREATEN, "substituted")
	return true


func _substitution_destination() -> Vector2:
	var away := global_position - _player.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT
	var behind := -away.normalized()
	var dist0 := float(profile.get("sub_behind_dist", 72.0))
	for d in [dist0, dist0 * 0.7, dist0 * 0.5]:
		for ang in [0.0, 0.5, -0.5, 1.0, -1.0]:
			var p: Vector2 = _player.global_position + behind.rotated(ang) * d
			if _substitution_spot_ok(p):
				return p
	return global_position


func _substitution_spot_ok(p: Vector2) -> bool:
	var arena := get_parent()
	if arena != null and arena.has_method("get_bounds"):
		var b: Rect2 = arena.get_bounds()
		if not b.grow(-8.0).has_point(p):
			return false
	return not test_move(Transform2D(0.0, p), Vector2(0.01, 0.0))


## 0..1 through the throw animation (windup 0..0.7, release at ~0.7, recovery to 1); -1 when not throwing.
func get_throw_progress() -> float:
	if state != State.ATTACK:
		return -1.0
	if atk_phase == AtkPhase.THROW_WINDUP:
		var total: float = float(profile.get("throw_windup", 0.42))
		return clampf(1.0 - _atk_timer / total, 0.0, 1.0) * THROW_RELEASE_AT
	if atk_phase == AtkPhase.THROW_RECOVERY:
		var rec: float = float(profile.get("throw_recovery", 0.3))
		return THROW_RELEASE_AT + clampf(1.0 - _atk_timer / rec, 0.0, 1.0) * (1.0 - THROW_RELEASE_AT)
	if atk_phase == AtkPhase.THROW_GAP:
		return THROW_RELEASE_AT
	return -1.0


func _begin_attack() -> void:
	_enter(State.ATTACK, "swing")
	atk_phase = AtkPhase.WINDUP1
	_atk_timer = float(profile.attack_windup)
	_atk_dir = (_player.global_position - global_position).normalized()
	_atk_hit_done = [false, false]
	_overcommit = _rng.randf() < float(profile.overcommit_chance)
	swings_thrown += 1
	velocity = Vector2.ZERO


func _tick_attack(delta: float) -> void:
	if atk_phase == AtkPhase.THROW_WINDUP or atk_phase == AtkPhase.THROW_RECOVERY or atk_phase == AtkPhase.THROW_GAP:
		_tick_throw(delta)
		return
	_atk_timer -= delta
	var windup: float = float(profile.attack_windup)
	match atk_phase:
		AtkPhase.WINDUP1, AtkPhase.WINDUP2:
			velocity = Vector2.ZERO
			# Aim tracks the player only through the first half of the tell, then freezes: a sidestep or
			# dodge after the freeze beats the swing. Overcommitted swing 2 never re-aims.
			var frozen := _atk_timer < windup * 0.5 or (atk_phase == AtkPhase.WINDUP2 and _overcommit)
			if not frozen and _player != null:
				_atk_dir = (_player.global_position - global_position).normalized()
			facing8 = WorldScale.snap8(_atk_dir)
			if _atk_timer <= 0.0:
				atk_phase = AtkPhase.ACTIVE1 if atk_phase == AtkPhase.WINDUP1 else AtkPhase.ACTIVE2
				_atk_timer = float(profile.attack_active)
		AtkPhase.ACTIVE1, AtkPhase.ACTIVE2:
			var idx := 0 if atk_phase == AtkPhase.ACTIVE1 else 1
			var lunge: float = float(profile.overcommit_lunge_speed) if (idx == 1 and _overcommit) else float(profile.lunge_speed)
			velocity = _atk_dir * lunge
			if not _atk_hit_done[idx]:
				_try_hit(idx)
			if _atk_timer <= 0.0:
				if idx == 0:
					atk_phase = AtkPhase.GAP
					_atk_timer = float(profile.combo_gap)
				else:
					atk_phase = AtkPhase.RECOVERY
					_atk_timer = float(profile.final_recovery) if _overcommit else float(profile.attack_recovery)
					if _overcommit:
						overcommits += 1
		AtkPhase.GAP:
			velocity = Vector2.ZERO
			if _atk_timer <= 0.0:
				atk_phase = AtkPhase.WINDUP2
				_atk_timer = windup * 0.8
		AtkPhase.RECOVERY:
			velocity = Vector2.ZERO
			if _atk_timer <= 0.0:
				_finish_attack()


func _try_hit(idx: int) -> void:
	if _player == null or not _player.has_method("take_hit"):
		_atk_hit_done[idx] = true
		return
	var to := _player.global_position - global_position
	if to.length() > float(profile.attack_reach):
		return
	if absf(_atk_dir.angle_to(to)) > deg_to_rad(float(profile.attack_arc_deg) * 0.5):
		return
	if not line_clear_to(_player.global_position):
		return  # no hits through walls
	if absf(float(_player.get("elevation") if "elevation" in _player else 0.0) - elevation) > ShrineElevation.HEIGHT * ShrineElevation.BOARD_AT:
		return  # no hits between a cliff top and the ground below it
	_atk_hit_done[idx] = true
	if _player.call("take_hit", 8.0, to.normalized(), 180.0, self):
		player_hits_landed += 1
		_log("hit %d landed" % (idx + 1))
		# Owner 2026-10-22: "try to steal it upon defeating players." No player death/HP system exists
		# yet (that is a locked RPG system, not changed here) -- a landed hit is the closest real combat
		# resolution event available today, so the steal is wired here. Flagged for owner confirmation.
		if is_worth_robbing(_player):
			_steal_ryo(_player)
	else:
		_log("hit %d evaded" % (idx + 1))


func _finish_attack() -> void:
	atk_phase = AtkPhase.NONE
	_atk_cooldown = float(profile.attack_cooldown)
	if _player == null:
		_enter(State.SEARCH, "no player")
		return
	if not _overcommit and _rng.randf() < float(profile.retreat_chance):
		_begin_retreat()
	elif _rng.randf() < 0.6:
		_begin_reposition()
	else:
		_enter(State.THREATEN, "next round")


func _begin_reposition() -> void:
	_enter(State.REPOSITION, "step back")
	_reposition_timer = float(profile.reposition_time)
	var away := (global_position - _player.global_position).normalized()
	_reposition_dir = _safe_direction(away, 140.0)


func _tick_reposition(delta: float) -> void:
	_reposition_timer -= delta
	if _player != null:
		_face(_player.global_position - global_position)
	velocity = _reposition_dir * float(profile.reposition_speed) if _reposition_dir != Vector2.ZERO else Vector2.ZERO
	if _reposition_timer <= 0.0:
		velocity = Vector2.ZERO
		_enter(State.THREATEN, "repositioned")


## First of `away` rotated 0/+-35/+-70 degrees whose first `probe` px are free; ZERO if all blocked.
func _safe_direction(away: Vector2, probe: float) -> Vector2:
	for deg: float in [0.0, 35.0, -35.0, 70.0, -70.0]:
		var d := away.rotated(deg_to_rad(deg))
		if not test_move(global_transform, d * probe):
			return d
	return Vector2.ZERO


## Rare retreat: telegraph, then TWO short backward Body Flicker hops with a beat between them.
func _begin_retreat() -> void:
	_enter(State.RETREAT, "double flicker")
	retreat_phase = RetreatPhase.TELEGRAPH
	_retreat_timer = float(profile.retreat_telegraph)
	velocity = Vector2.ZERO


func _tick_retreat(delta: float) -> void:
	_retreat_timer -= delta
	flicker_hopping = retreat_phase in [RetreatPhase.HOP1, RetreatPhase.HOP2]
	match retreat_phase:
		RetreatPhase.TELEGRAPH:
			velocity = Vector2.ZERO
			if _player != null:
				_face(_player.global_position - global_position)
			if _retreat_timer <= 0.0:
				_start_hop(RetreatPhase.HOP1)
		RetreatPhase.HOP1, RetreatPhase.HOP2:
			# Burst exactly `hop_time` long, never overshooting into a wall (hop length was validated).
			var frac := clampf((_retreat_timer + delta) / maxf(delta, 0.00001), 0.0, 1.0)
			velocity = _retreat_hop_velocity * frac
			if _retreat_timer <= 0.0:
				velocity = Vector2.ZERO
				flicker_hopping = false
				if retreat_phase == RetreatPhase.HOP1:
					retreat_phase = RetreatPhase.PAUSE
					_retreat_timer = float(profile.flicker_pause)
				else:
					retreat_phase = RetreatPhase.RECOVER
					_retreat_timer = float(profile.retreat_recovery)
		RetreatPhase.PAUSE:
			velocity = Vector2.ZERO
			if _retreat_timer <= 0.0:
				_start_hop(RetreatPhase.HOP2)
		RetreatPhase.RECOVER:
			velocity = Vector2.ZERO
			if _retreat_timer <= 0.0:
				retreat_phase = RetreatPhase.NONE
				flicker_hopping = false
				_atk_cooldown = maxf(_atk_cooldown, float(profile.attack_cooldown))
				_enter(State.APPROACH if sees_player else State.SEARCH, "retreat done")


func _start_hop(phase: RetreatPhase) -> void:
	var away := Vector2.LEFT
	if _player != null:
		away = (global_position - _player.global_position).normalized()
	var dist: float = float(profile.flicker_distance)
	var dir := Vector2.ZERO
	var hop := 0.0
	# Longest safe hop first, then shorter, then slightly angled; a hop shorter than 60 px is skipped.
	for deg: float in [0.0, 30.0, -30.0]:
		var d := away.rotated(deg_to_rad(deg))
		for sc: float in [1.0, 0.75, 0.5, 0.3]:
			if dist * sc >= 60.0 and not test_move(global_transform, d * dist * sc):
				dir = d
				hop = dist * sc
				break
		if hop > 0.0:
			break
	if hop <= 0.0:
		_retreat_hop_velocity = Vector2.ZERO
		_log("flicker hop blocked, skipped")
	else:
		_retreat_hop_velocity = dir * hop / float(profile.flicker_hop_time)
		flicker_count += 1
		_log("flicker hop %d: %d px" % [1 if phase == RetreatPhase.HOP1 else 2, int(hop)])
		facing8 = WorldScale.snap8(-dir)
	retreat_phase = phase
	_retreat_timer = float(profile.flicker_hop_time)
	flicker_hopping = true


func _tick_search(delta: float) -> void:
	if sees_player:
		_enter(State.NOTICE, "re-spotted")
		return
	if not _search_arrived:
		velocity = Vector2.ZERO
		if _follow(last_seen, move_speed * 0.6, delta, 30.0):
			_search_arrived = true
			_look_base = facing8
			_look_timer = 0.0
			_look_step = 0
		return
	velocity = Vector2.ZERO
	_look_around(delta)
	_search_timer -= delta
	if _search_timer <= 0.0:
		_enter(State.RETURN, "gave up")


func _tick_return(delta: float) -> void:
	if sees_player:
		_enter(State.NOTICE, "spotted while returning")
		return
	# Owner 2026-10-22: "I want the logic for all enemies to stay in their new area." `home` was already
	# snapped to this exact spot on RETURN entry (see _enter), so there is nowhere to walk back to --
	# this just settles for a brief beat (looking around, not frozen) before resuming patrol from here.
	velocity = Vector2.ZERO
	is_sprinting = false
	_look_around(delta)
	_return_settle_timer -= delta
	if _return_settle_timer <= 0.0:
		_enter(State.PATROL, "settled into new area")


# ---------------------------------------------------------------------------------- movement
## Moves toward `goal` around walls. Returns true once within `arrive` px. Sets velocity; the caller's
## move_and_slide applies it.
func _follow(goal: Vector2, speed: float, delta: float, arrive: float, turn_beat: bool = true) -> bool:
	var to_goal := goal - global_position
	if to_goal.length() <= arrive:
		velocity = Vector2.ZERO
		_moving_intent = false
		return true
	var target := goal
	var climb := ShrineElevation.climb_step(global_position, goal)
	if not climb.is_empty():
		goal = climb.target
		target = goal
	if nav != null and not bool(climb.get("direct", false)):
		_repath_timer -= delta
		if _path.is_empty() or _repath_timer <= 0.0 or goal.distance_to(_path_goal) > 90.0:
			_path = nav.find_path(global_position, goal)
			_path_idx = 0
			_path_goal = goal
			_repath_timer = float(profile.repath_interval)
			path_requests += 1
		while _path_idx < _path.size() - 1 and global_position.distance_to(_path[_path_idx]) < 30.0:
			_path_idx += 1
		if _path_idx < _path.size():
			target = _path[_path_idx]
	var dir := (target - global_position).normalized()
	_moving_intent = true
	if turn_beat:
		_face_for_travel(dir)
	else:
		_face(dir)
	if _turn_pause > 0.0:
		velocity = Vector2.ZERO
		return false
	velocity = dir * speed
	return false


func _face(v: Vector2) -> void:
	if v.length_squared() > 1.0:
		facing8 = WorldScale.snap8(v.normalized())


## Facing while travelling: a big turn (>= 90 deg) costs a short stop-to-turn beat instead of a snap.
func _face_for_travel(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	var next := WorldScale.snap8(dir)
	if next == facing8:
		return
	if absf(facing8.angle_to(next)) >= deg_to_rad(89.0):
		_turn_pause = 0.14
		turn_pauses += 1
	facing8 = next


## Idle look-around so a guard never freezes like a mannequin: base, +45, base, -45 ...
func _look_around(delta: float) -> void:
	_look_timer -= delta
	if _look_timer > 0.0:
		return
	_look_timer = 0.8
	var offsets := [0.0, 45.0, 0.0, -45.0, 90.0, 0.0, -90.0]
	_look_step = (_look_step + 1) % offsets.size()
	facing8 = WorldScale.snap8(_look_base.rotated(deg_to_rad(float(offsets[_look_step]))))


func _check_stuck(delta: float) -> void:
	if not _moving_intent or _turn_pause > 0.0:
		_stuck_timer = 0.0
		_stuck_ref = global_position
		return
	_stuck_timer += delta
	if _stuck_timer >= 0.8:
		if global_position.distance_to(_stuck_ref) < 12.0:
			stuck_events += 1
			_repath_timer = 0.0
			_log("stuck, repath")
		_stuck_timer = 0.0
		_stuck_ref = global_position
	_moving_intent = false


# ---------------------------------------------------------------------------------- evade (legacy)
func _attack_ready() -> bool:
	return _threaten_timer <= 0.0 and _atk_cooldown <= 0.0 and state == State.THREATEN


func _should_evade(to_player: Vector2) -> bool:
	if _evade_cooldown > 0.0 or to_player.length() > 260.0 or to_player.length_squared() < 1.0:
		return false
	if _attack_ready():
		return false  # an attack that is ready goes first; evading is for its cooldown window
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
		_enter(State.EVADE, "dodge")
		is_sprinting = true
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
	if flicker_hopping or _sub_invuln > 0.0:
		return  # mid-flicker (or just after a log swap) the body is not there to be hit
	if _try_substitution():
		return  # log took the hit
	hp = maxf(hp - amount, 0.0)
	_hit_flash_timer = hit_flash_duration
	_hitstop_timer = maxf(_hitstop_timer, hitstop_ms / 1000.0)
	atk_phase = AtkPhase.NONE
	retreat_phase = RetreatPhase.NONE
	flicker_hopping = false
	if hp <= 0.0:
		_log("defeated")
		state = State.DEAD
		_death_time = 0.0
		react_kind = "death"
		velocity = knockback_dir * maxf(knockback_speed, 140.0) * 0.9  # the body is thrown, then skids to a stop
		visual.queue_redraw()
		defeated.emit()
		return
	if state in [State.ATTACK, State.THREATEN, State.REPOSITION, State.RETREAT]:
		_atk_cooldown = maxf(_atk_cooldown, float(profile.attack_cooldown) * 0.5)
	_enter(State.HIT_REACT, "damaged")
	var big := knockback_speed >= KNOCKBACK_ANIM_SPEED
	react_kind = "knockback" if big else "hit_react"
	react_duration = maxf(hit_react_duration, KNOCKBACK_CLIP if big else HIT_REACT_CLIP)
	_hit_react_timer = react_duration
	velocity = knockback_dir * knockback_speed * (1.25 if big else 1.0)


## 0..1 progress through the current hurt clip (hit_react / knockback).
func react_progress() -> float:
	return clampf(1.0 - _hit_react_timer / maxf(react_duration, 0.001), 0.0, 1.0)


func is_alive() -> bool:
	return state != State.DEAD


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var players := get_tree().get_nodes_in_group("player")
	_player = players[0] if players.size() > 0 else null


func get_state_name() -> String:
	return State.keys()[state]


## Short human-readable description of what the bandit is trying to do (HUD / debug / smoke state).
func get_intent() -> String:
	match state:
		State.PATROL, State.IDLE:
			return "patrolling"
		State.NOTICE:
			return "noticing"
		State.APPROACH:
			return "chasing" if sees_player else "following last seen"
		State.THREATEN:
			return "threatening"
		State.ATTACK:
			return "attacking:" + AtkPhase.keys()[atk_phase].to_lower()
		State.REPOSITION:
			return "repositioning"
		State.RETREAT:
			return "retreating:" + RetreatPhase.keys()[retreat_phase].to_lower()
		State.SEARCH:
			return "searching"
		State.RETURN:
			return "returning"
		State.EVADE:
			return "dodging"
		State.HIT_REACT:
			return "staggered"
	return "down"


func get_attack_progress() -> float:
	## 0..1 through the CURRENT windup (telegraph strength for the visual); 0 outside windups.
	if state == State.ATTACK and atk_phase in [AtkPhase.WINDUP1, AtkPhase.WINDUP2]:
		var total: float = float(profile.attack_windup) * (1.0 if atk_phase == AtkPhase.WINDUP1 else 0.8)
		return clampf(1.0 - _atk_timer / total, 0.0, 1.0)
	if state == State.RETREAT and retreat_phase == RetreatPhase.TELEGRAPH:
		return clampf(1.0 - _retreat_timer / float(profile.retreat_telegraph), 0.0, 1.0)
	return 0.0


func get_notice_progress() -> float:
	if state != State.NOTICE:
		return 0.0
	return clampf(_notice_timer / (float(profile.notice_delay) * (1.6 if _has_lost_player else 1.0)), 0.0, 1.0)
