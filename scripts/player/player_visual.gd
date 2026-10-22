class_name PlayerVisual
extends Node2D
## Swaps between the labeled PLACEHOLDER visual (default) and a SpriteSet from the SpriteLibrary.
## Uses the first valid set unless the lab picks another. The foot anchor sits on the player origin;
## the collision footprint and shadow never move when animations change.

const CHAIN_IDLE: Array[String] = ["idle", "run", "walk"]
const CHAIN_RUN: Array[String] = ["run", "walk"]
const CHAIN_SPRINT: Array[String] = ["sprint", "run", "walk"]

signal sprite_set_changed(new_set: SpriteSet)

@onready var placeholder: PlaceholderVisual = $PlaceholderVisual

var actor: SpriteActor
var sprite_set: SpriteSet
var last_anim: String = ""
var last_dir: String = ""
var _pose: Array = [Vector2.DOWN, false, false]

## Kunai weapon overlay (owner 2026-10-22: "wire it to the controller"). Only ever shown while the
## body literally resolved to a SE facing for a WeaponRig-known attack id -- see WeaponRig's doc
## comment and the gating in play_action() below. Hidden by every other code path in this file.
var _weapon_grip: Node2D
var _weapon_blade: Sprite2D


func _ready() -> void:
	actor = SpriteActor.new()
	actor.name = "SpriteActor"
	actor.visible = false
	add_child(actor)
	_weapon_grip = Node2D.new()
	_weapon_grip.name = "WeaponGrip"
	_weapon_grip.visible = false
	add_child(_weapon_grip)
	_weapon_blade = Sprite2D.new()
	_weapon_blade.name = "WeaponBlade"
	_weapon_blade.centered = false
	_weapon_blade.texture = load(WeaponRig.WEAPON_TEXTURE)
	_weapon_blade.position = -WeaponRig.GRIP_PIVOT_PX
	_weapon_grip.add_child(_weapon_blade)
	set_sprite_set(SpriteLibrary.get_instance().first_valid())


## Animation id for the gameplay state. no input -> idle; moving -> run (else walk); sprint -> sprint.
## Missing ids fall back (sprint -> run -> walk, idle -> idle/walk/run frame 0). "" = none usable.
static func pick_animation(s: SpriteSet, moving: bool, sprinting: bool) -> String:
	var chain: Array[String] = CHAIN_IDLE
	if moving:
		chain = CHAIN_SPRINT if sprinting else CHAIN_RUN
	for aid: String in chain:
		if s.animations.has(aid):
			return aid
	return ""


func set_sprite_set(s: SpriteSet) -> void:
	if s != null and not s.is_valid():
		s = null
	sprite_set = s
	last_anim = ""
	last_dir = ""
	actor.visible = s != null
	placeholder.visible = s == null
	_weapon_grip.visible = false  ## never carry a visible kunai across a set switch (e.g. Animation Lab)
	if s == null:
		actor.queue_redraw()
	sprite_set_changed.emit(s)
	_apply()


func set_pose(dir8: Vector2, sprinting: bool, moving: bool) -> void:
	_pose = [dir8, sprinting, moving]
	_weapon_grip.visible = false  ## locomotion never shows the weapon overlay
	if sprite_set == null:
		placeholder.set_pose(dir8, sprinting, moving)
		return
	_apply()


## One-shot action override (dodge, jump): shows `aid` facing `dir8` regardless of the normal
## idle/run/sprint chain. Returns false (no sprite set, or the animation is missing) so the caller
## can fall back to the placeholder's canned motion. Call every physics frame while the action is
## active; show_animation() is cheap when the (set, anim, dir) key is unchanged.
func play_action(aid: String, dir8: Vector2) -> bool:
	if sprite_set == null or not sprite_set.animations.has(aid):
		_weapon_grip.visible = false
		return false
	# Owner 2026-10-22 ("wire it to the controller"): Codex's kunai strike art is SE-only (see
	# WeaponRig's doc comment -- the order gates expansion to the other 7 directions behind separate
	# owner approval). SpriteSet.resolve()'s normal nearest-neighbor fallback would otherwise show this
	# SE pose for ANY facing, visibly snapping the body to the wrong direction mid-attack. Combat ids
	# WeaponRig knows about are restricted to a literal SE facing; every other facing keeps the
	# pre-existing behavior (whatever locomotion pose was last applied stays frozen for the attack's
	# duration), unchanged from before this animation existed.
	if WeaponRig.supports(aid) and SpriteSet.dir_name(dir8) != "SE":
		_weapon_grip.visible = false
		return false
	var shown := actor.show_animation(sprite_set, aid, SpriteSet.dir_name(dir8), false)
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
		_update_weapon(aid)
	else:
		_weapon_grip.visible = false
	return shown


## Like play_action(), but the frame follows `progress` (0..1) of the action instead of free-running.
## No WeaponRig-known attack id currently uses progress-based playback; the weapon overlay is hidden
## unconditionally here so it can never linger visible from a prior play_action() call.
func play_action_progress(aid: String, dir8: Vector2, progress: float) -> bool:
	_weapon_grip.visible = false
	if sprite_set == null or not sprite_set.animations.has(aid):
		return false
	var shown := actor.show_animation_at(sprite_set, aid, SpriteSet.dir_name(dir8), progress)
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
	return shown


## True when the active sprite set has authored art for `aid`.
func has_action(aid: String) -> bool:
	return sprite_set != null and sprite_set.animations.has(aid)


## True while the kunai weapon overlay is currently showing (see WeaponRig / play_action()).
func weapon_visible() -> bool:
	return _weapon_grip != null and _weapon_grip.visible


## Positions/rotates/shows the kunai weapon overlay for the current body frame of a WeaponRig-known
## attack id, or hides it if unsupported/no pose data. Only called from play_action() after it has
## already confirmed a literal SE facing (actor.dir == "SE", never a mirror or nearest-neighbor
## fallback) -- the extra actor.dir/actor.flip check here is defensive, not the primary gate.
func _update_weapon(aid: String) -> void:
	if not WeaponRig.supports(aid) or actor.dir != "SE" or actor.flip:
		_weapon_grip.visible = false
		return
	var p := WeaponRig.pose(aid, actor.current_frame())
	if p.is_empty():
		_weapon_grip.visible = false
		return
	_weapon_grip.position = (p["hand"] as Vector2) - sprite_set.anim_anchor(aid)
	_weapon_grip.rotation = deg_to_rad(float(p["angle_deg"]))
	_weapon_grip.z_index = -1 if p["layer"] == "behind" else 1
	_weapon_grip.visible = true


## Seconds `aid` plays for one cycle (frame count / fps from the manifest), or `fallback` if the
## current sprite set has no such animation (placeholder visual: there is no authored timing).
func action_duration(aid: String, fallback: float) -> float:
	if sprite_set != null and sprite_set.animations.has(aid):
		var d := sprite_set.anim_duration(aid)
		if d > 0.0:
			return d
	return fallback


func _apply() -> void:
	if sprite_set == null:
		return
	var moving: bool = _pose[2]
	var aid := pick_animation(sprite_set, moving, _pose[1])
	if aid.is_empty():
		actor.visible = false
		placeholder.visible = true
		placeholder.set_pose(_pose[0], _pose[1], moving)
		return
	var shown := actor.show_animation(sprite_set, aid, SpriteSet.dir_name(_pose[0]), not moving and aid != "idle")
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
	else:
		placeholder.set_pose(_pose[0], _pose[1], moving)
