class_name AttackDef
extends RefCounted
## Tuning data for one player attack (light combo hit or dash attack). All frame counts are at
## `FRAMES_PER_SECOND` (the order's tuning table); seconds are derived so gameplay code never
## hardcodes a frame rate. These are INITIAL TUNING TARGETS per the combat order, not locked values.

const FRAMES_PER_SECOND := 60.0

var id: String
var startup: float  ## seconds before the hit becomes active (can't be canceled by anything but a dodge-cancel/parry rule)
var active: float  ## seconds the hitbox can land a hit
var recovery: float  ## seconds after the active window before the attack fully resolves
var damage: float
var reach: float  ## hit arc radius (px) from the player's feet, forward along facing8
var arc_half_angle_deg: float  ## half-width (degrees) of the forward hit arc around facing8
var lunge: float  ## forward velocity burst (px/s) applied along facing8 the instant the attack begins
var hitstop_ms: float  ## local hitstop applied to attacker+target on a successful hit (not a global freeze)
var knockback: float  ## px/s applied to the target along the hit direction
var combo_window: float  ## seconds, measured from the start of recovery, during which a buffered next-attack
## press continues the combo (cutting the remaining recovery short); after this window closes the combo drops
## back to the first hit.
var dodge_cancel_from: float  ## seconds into recovery after which a dodge press cancels the remaining recovery
## (early recovery is "committed"; this is 0.0 for moves with no commitment at all).

func _init(p_id: String, p_startup_f: float, p_active_f: float, p_recovery_f: float, p_damage: float,
		p_reach: float, p_arc_half_angle_deg: float, p_lunge: float, p_hitstop_ms: float, p_knockback: float,
		p_combo_window_f: float, p_dodge_cancel_from_f: float) -> void:
	id = p_id
	startup = p_startup_f / FRAMES_PER_SECOND
	active = p_active_f / FRAMES_PER_SECOND
	recovery = p_recovery_f / FRAMES_PER_SECOND
	damage = p_damage
	reach = p_reach
	arc_half_angle_deg = p_arc_half_angle_deg
	lunge = p_lunge
	hitstop_ms = p_hitstop_ms
	knockback = p_knockback
	combo_window = p_combo_window_f / FRAMES_PER_SECOND
	dodge_cancel_from = p_dodge_cancel_from_f / FRAMES_PER_SECOND

func total_duration() -> float:
	return startup + active + recovery


## All attack defs in one place so tuning (per the order's table: frame counts at 60 tps) lives in
## one readable spot. Reach/arc/lunge/knockback/damage are first-pass gameplay numbers -- not balance,
## same provisional-prototype status as WorldScale's movement constants.
static func build_table() -> Dictionary:
	var t := {}
	# id, startup, active, recovery, damage, reach, arc_half_angle, lunge, hitstop_ms, knockback, combo_window, dodge_cancel_from
	t["light1"] = AttackDef.new("light1", 5, 4, 9, 10.0, 95.0, 40.0, 90.0, 40.0, 140.0, 7, 3)
	t["light2"] = AttackDef.new("light2", 6, 4, 11, 13.0, 100.0, 40.0, 100.0, 45.0, 170.0, 8, 4)
	t["light3"] = AttackDef.new("light3", 9, 5, 15, 20.0, 110.0, 45.0, 60.0, 75.0, 260.0, 9, 6)
	t["dash_attack"] = AttackDef.new("dash_attack", 6, 5, 13, 16.0, 120.0, 35.0, 320.0, 55.0, 220.0, 0, 4)
	return t
