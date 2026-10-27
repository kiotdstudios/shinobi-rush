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

var locomotion := LocomotionTransition.new()

var actor: SpriteActor
var sprite_set: SpriteSet
var last_anim: String = ""
var last_dir: String = ""
var _pose: Array = [Vector2.DOWN, false, false]

## Frame-driven weapon, hand occlusion and independent contact trail shared with the bandit.
var weapon_layer: KunaiWeaponVisual


func _ready() -> void:
	actor = SpriteActor.new()
	actor.name = "SpriteActor"
	actor.visible = false
	add_child(actor)
	weapon_layer=KunaiWeaponVisual.new()
	weapon_layer.name="KunaiWeapon"
	weapon_layer.visible=false
	add_child(weapon_layer)
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
	locomotion.interrupt()
	last_anim = ""
	last_dir = ""
	actor.visible = s != null
	placeholder.visible = s == null
	weapon_layer.visible = false  ## never carry a visible kunai across a set switch (e.g. Animation Lab)
	if s == null:
		actor.queue_redraw()
	sprite_set_changed.emit(s)
	_apply()


func set_pose(dir8: Vector2, sprinting: bool, moving: bool) -> void:
	locomotion.interrupt()
	_pose = [dir8, sprinting, moving]
	weapon_layer.visible = false  ## locomotion never shows the weapon overlay
	if sprite_set == null:
		placeholder.set_pose(dir8, sprinting, moving)
		return
	_apply()


## Traversal entry point; delta belongs to the physics clock, not render FPS.
func set_locomotion(delta: float, dir8: Vector2, sprinting: bool, moving: bool, travel: Vector2) -> void:
	_pose = [dir8, sprinting, moving]
	weapon_layer.visible = false
	locomotion.update(delta, moving, travel, dir8, sprinting)
	if sprite_set == null:
		placeholder.set_pose(dir8, sprinting, moving)
		return
	if sprite_set != null and locomotion.show(actor, sprite_set):
		actor.visible = true
		placeholder.visible = false
		last_anim = actor.anim_id
		last_dir = actor.dir
		return
	_apply()
	if locomotion.completed and moving and actor.sprite.sprite_frames != null:
		# Continue after the final push-off pose rather than replaying frame zero.
		actor.sprite.set_frame_and_progress(mini(3, actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)-1), 0.0)


## One-shot action override (dodge, jump): shows `aid` facing `dir8` regardless of the normal
## idle/run/sprint chain. Returns false (no sprite set, or the animation is missing) so the caller
## can fall back to the placeholder's canned motion. Call every physics frame while the action is
## active; show_animation() is cheap when the (set, anim, dir) key is unchanged.
func play_action(aid: String, dir8: Vector2) -> bool:
	if sprite_set == null or not sprite_set.animations.has(aid):
		weapon_layer.visible = false
		return false
	# Every production heading has literal art; never substitute the old SE body for another facing.
	if WeaponRig.supports(aid) and sprite_set.id=="player_128" and KunaiCombatData.frames("player",SpriteSet.dir_name(dir8),aid).is_empty():
		weapon_layer.visible=false
		return false
	locomotion.interrupt()
	var shown := actor.show_animation(sprite_set, aid, SpriteSet.dir_name(dir8), false)
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
		_update_weapon(aid)
	else:
		weapon_layer.visible = false
	return shown


## Like play_action(), but the frame follows `progress` (0..1) of the action instead of free-running.
## Kunai body/weapon keys follow the same explicit per-frame timing data.
func play_action_progress(aid: String, dir8: Vector2, progress: float) -> bool:
	weapon_layer.visible = false
	if sprite_set == null or not sprite_set.animations.has(aid):
		return false
	locomotion.interrupt()
	var shown := actor.show_animation_at(sprite_set, aid, SpriteSet.dir_name(dir8), progress)
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
		if WeaponRig.supports(aid) and sprite_set.id=="player_128" and not actor.flip and not actor.fallback:
			var pose := KunaiCombatData.pose_at("player",actor.dir,aid,clampf(progress,0.0,1.0)*float(KunaiCombatData.profile(aid).duration_ms))
			if not pose.is_empty():
				actor.sprite.set_frame_and_progress(int(pose.frame_index),0.0)
				weapon_layer.show_for(actor,pose)
	return shown


## True when the active sprite set has authored art for `aid`.
func has_action(aid: String) -> bool:
	return sprite_set != null and sprite_set.animations.has(aid)


## True while the complete attachment layer is presented.
func weapon_visible() -> bool:
	return weapon_layer!=null and weapon_layer.visible


## Drive body and weapon from the SAME gameplay phase. Hitstop freezes this frame naturally.
func _update_weapon(aid: String) -> void:
	if not WeaponRig.supports(aid) or sprite_set.id!="player_128" or actor.flip or actor.fallback:
		weapon_layer.visible=false
		return
	var poses := KunaiCombatData.frames("player",actor.dir,aid)
	if poses.is_empty():
		weapon_layer.visible=false
		return
	var pose: Dictionary=poses[clampi(actor.current_frame(),0,poses.size()-1)]
	var player := get_parent() as PlayerController
	if player!=null and player._attack_def!=null and player._attack_def.id==aid:
		var phase := "startup"
		var duration := player._attack_def.startup
		if player._attack_phase==PlayerController.AttackPhase.ACTIVE:
			phase="active"
			duration=player._attack_def.active
		elif player._attack_phase==PlayerController.AttackPhase.RECOVERY:
			phase="recovery"
			duration=player._attack_def.recovery
		pose=KunaiCombatData.pose_for_phase("player",actor.dir,aid,phase,1.0-player._attack_timer/maxf(duration,0.00001))
	if pose.is_empty():
		weapon_layer.visible=false
		return
	actor.sprite.pause()
	actor.sprite.set_frame_and_progress(int(pose.frame_index),0.0)
	weapon_layer.show_for(actor,pose)


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
