class_name BanditVisual
extends Node2D
## Explicit enemy-only binding of Codex's 128px red-scarf bandit art.
## Missing art/death retain the procedural fallback until dedicated action art is available.

const ART_PATH := "res://assets/characters/bandit/bandit_128.art.json"
static var _art_set: SpriteSet
static var _art_checked := false

@export_enum("auto", "run", "sprint") var approach_animation: String = "auto"
var streak: AnimatedSprite2D
var _last_evade := 0
var _last_flicker := 0
var actor: SpriteActor
var weapon_layer: KunaiWeaponVisual

const CLOTH := Color("#5a3a2a")
const LIMB := Color("#3a2a1a")
const SKIN := Color("#8a4a3a")
const DEAD_TINT := Color("#555555")
const MOVING_STATES := [Bandit.State.APPROACH, Bandit.State.EVADE, Bandit.State.PATROL, Bandit.State.SEARCH, Bandit.State.RETURN, Bandit.State.REPOSITION]
const SLASH_COLOR := Color(1.0, 0.85, 0.6, 0.9)
const TELL_COLOR := Color(1.0, 0.2, 0.15)

var bandit: Bandit


func _ready() -> void:
	bandit = get_parent() as Bandit
	actor = SpriteActor.new()
	actor.name = "BanditSprite"
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(actor)
	weapon_layer=KunaiWeaponVisual.new()
	weapon_layer.name="KunaiWeapon"
	weapon_layer.visible=false
	add_child(weapon_layer)
	if not _art_checked:
		_art_checked = true
		_art_set = SpriteSet.parse(FileAccess.get_file_as_string(ART_PATH), ART_PATH)
		if not _art_set.is_valid():
			push_warning("Bandit art unavailable: " + _art_set.first_error())
	streak = AnimatedSprite2D.new()
	streak.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	streak.sprite_frames = SpriteFrames.new()
	streak.sprite_frames.set_animation_loop("default", false)
	streak.sprite_frames.set_animation_speed("default", 30.0)
	for i in 6:
		streak.sprite_frames.add_frame("default", load("res://assets/vfx/ninja_evade/streak_%03d.png" % i))
	streak.position = Vector2(0, -48)
	streak.visible = false
	add_child(streak)
	_process(0.0)


func _process(_delta: float) -> void:
	if bandit == null or actor == null:
		return
	actor.visible = _art_set != null and _art_set.is_valid() and bandit.state != Bandit.State.DEAD
	if not actor.visible:weapon_layer.visible=false
	if actor.visible:
		var combat_pose := _show_kunai_pose()
		var moving := bandit.state in MOVING_STATES and bandit.velocity.length_squared() > 1.0
		# Knockback is not a running cycle. Keep the struck pose through hurt/hitstop.
		if not combat_pose and (bandit.state != Bandit.State.HIT_REACT or actor.set_ref == null):
			var action := "idle"
			if moving:
				action = ("sprint" if bandit.is_sprinting else "run") if approach_animation == "auto" else approach_animation
			# Preserve gait phase across octant and run/sprint changes; idle still starts deliberately.
			var preserve := moving and actor.anim_id in ["run", "sprint"]
			var phase := 0.0
			if preserve:
				phase = (actor.sprite.frame + actor.sprite.frame_progress) / float(actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation))
			actor.show_animation(_art_set, action, SpriteSet.dir_name(bandit.facing8))
			if preserve:
				var frame := phase * actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
				actor.sprite.set_frame_and_progress(int(frame), frame - floorf(frame))
		# Slow walking states reuse the run cycle at a matching cadence (no dedicated walk art yet).
		var cadence := 1.0
		if moving and not bandit.is_sprinting and bandit.state != Bandit.State.EVADE:
			cadence = clampf(bandit.velocity.length() / bandit.move_speed, 0.4, 1.0)
		if combat_pose:actor.sprite.pause()
		else:actor.set_playback(cadence, bandit._hitstop_timer > 0.0 or bandit.state == Bandit.State.HIT_REACT)
		var tint := Color.WHITE
		var tell := bandit.get_attack_progress()
		if bandit._hit_flash_timer > 0.0:
			tint = Bandit.HIT_FLASH
		elif bandit.state == Bandit.State.ATTACK and tell > 0.0:
			tint = Color(1.0, 1.0 - 0.55 * tell, 1.0 - 0.55 * tell)  # reddens as the swing nears
		elif bandit.state == Bandit.State.RETREAT and tell > 0.0:
			tint = Color(1.0 - 0.3 * tell, 0.9, 1.0)  # cold flash before the flicker
		if bandit.flicker_hopping:
			tint.a = 0.12  # mid-flicker the body is barely there
		actor.modulate = tint
		weapon_layer.modulate=tint
	if streak != null:
		if bandit.evade_count != _last_evade:
			_last_evade = bandit.evade_count
			streak.rotation = bandit.velocity.angle()
			streak.visible = true
			streak.play("default")
			streak.set_frame_and_progress(0, 0.0)
		if bandit.flicker_count != _last_flicker:
			_last_flicker = bandit.flicker_count
			streak.rotation = bandit._retreat_hop_velocity.angle()
			streak.visible = true
			streak.play("default")
			streak.set_frame_and_progress(0, 0.0)
		if bandit.state != Bandit.State.EVADE and bandit.state != Bandit.State.RETREAT:
			streak.visible = false
		elif bandit.state == Bandit.State.RETREAT and not streak.is_playing():
			streak.visible = false
		streak.speed_scale = 0.0 if bandit._hitstop_timer > 0.0 else 1.0
	queue_redraw()


func weapon_visible() -> bool:
	return weapon_layer!=null and weapon_layer.visible


## Uses Aki's existing phase/timer values read-only. Does not choose attacks or change damage/AI.
func _show_kunai_pose() -> bool:
	if bandit.state==Bandit.State.HIT_REACT and weapon_layer.visible:
		return true  # preserve the struck body and its matching hand/blade through knockback/hitstop
	var dir := SpriteSet.dir_name(bandit.facing8)
	var aid := "guard"
	var phase := "guard"
	var progress := 0.0
	if bandit.state==Bandit.State.ATTACK:
		var duration := 1.0
		match bandit.atk_phase:
			Bandit.AtkPhase.WINDUP1:
				aid="light1";phase="startup";duration=float(bandit.profile.attack_windup)
			Bandit.AtkPhase.ACTIVE1:
				aid="light1";phase="active";duration=float(bandit.profile.attack_active)
			Bandit.AtkPhase.GAP:
				aid="light1";phase="recovery";duration=float(bandit.profile.combo_gap)
			Bandit.AtkPhase.WINDUP2:
				aid="light2";phase="startup";duration=float(bandit.profile.attack_windup)*0.8
			Bandit.AtkPhase.ACTIVE2:
				aid="light2";phase="active";duration=float(bandit.profile.attack_active)
			Bandit.AtkPhase.RECOVERY:
				aid="light2";phase="recovery";duration=float(bandit.profile.final_recovery if bandit._overcommit else bandit.profile.attack_recovery)
			_:
				weapon_layer.visible=false
				return false
		progress=1.0-bandit._atk_timer/maxf(duration,0.00001)
	elif bandit.state!=Bandit.State.THREATEN:
		weapon_layer.visible=false
		return false
	return show_attack_pose(aid,dir,phase,progress)


## All four shared attack IDs are available to future enemy profiles; the existing AI still chooses two swings.
func show_attack_pose(aid: String, direction: String, phase: String, progress: float) -> bool:
	var pose := KunaiCombatData.pose_for_phase("bandit",direction,aid,phase,progress)
	if pose.is_empty():
		weapon_layer.visible=false
		return false
	var animation := "kunai_guard" if aid=="guard" else aid
	if not actor.show_animation(_art_set,animation,direction,aid=="guard"):
		weapon_layer.visible=false
		return false
	actor.sprite.pause()
	actor.sprite.set_frame_and_progress(int(pose.frame_index),0.0)
	weapon_layer.show_for(actor,pose)
	return true


func _draw() -> void:
	if bandit == null:
		return
	if actor != null and actor.visible:
		_draw_hp_and_label(-122.0)
		_draw_intent_overlays()
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * WorldScale.FIGURE_SCALE)
	var dead := bandit.state == Bandit.State.DEAD
	var flashing := bandit._hit_flash_timer > 0.0
	var cloth := DEAD_TINT if dead else (Bandit.HIT_FLASH if flashing else CLOTH)
	var limb := DEAD_TINT if dead else LIMB
	var skin := DEAD_TINT if dead else SKIN
	var hip := Vector2(0, -20) if not dead else Vector2(0, -6)
	var neck := hip + Vector2(0, -22)
	var head := neck + Vector2(0, -8)
	if dead:
		# Collapsed silhouette: a low horizontal shape instead of a standing figure.
		draw_line(Vector2(-14, -4), Vector2(14, -2), cloth, 10.0)
		draw_circle(Vector2(18, -3), 6.0, skin)
		_draw_hp_and_label()
		return
	var stride := 4.0 if bandit.state == Bandit.State.APPROACH else 0.0
	draw_line(hip, Vector2(-5 - stride, 0), limb, 4.0)
	draw_line(hip, Vector2(5 + stride, 0), limb, 4.0)
	draw_line(hip, neck, cloth, 9.0)
	var shoulder := neck + Vector2(0, 3)
	draw_line(shoulder + Vector2(-5, 0), shoulder + Vector2(-8, 14), limb, 3.0)
	draw_line(shoulder + Vector2(5, 0), shoulder + Vector2(8, 14), limb, 3.0)
	draw_circle(head, 7.0, skin)
	draw_circle(head + Vector2(bandit.facing8.x * 4.0, bandit.facing8.y * 2.0), 2.0, Color("#ffd23f"))
	_draw_hp_and_label()


func _draw_hp_and_label(top_y: float = -78.0) -> void:
	var font := ThemeDB.fallback_font
	var top := Vector2(-30, top_y)
	draw_string(font, top + Vector2(0, -6), "BANDIT L%d (%s)" % [bandit.intelligence_level, bandit.get_state_name()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
	if bandit.state == Bandit.State.DEAD:
		return
	var w := 60.0
	var h := 6.0
	draw_rect(Rect2(top, Vector2(w, h)), Color(0, 0, 0, 0.5), true)
	var frac := clampf(bandit.hp / bandit.max_hp, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(w * frac, h)), Color("#c0392b"), true)
	draw_rect(Rect2(top, Vector2(w, h)), Color(1, 1, 1, 0.6), false, 1.0)


## Code-drawn telegraphs and status marks. These are placeholders for Codex's dedicated alert/attack
## art (see orders/Codex/2026-10-21-bandit-level1-action-art.md); they are drawn above the sprite and
## carry no collision, so they never block anything.
func _draw_intent_overlays() -> void:
	var font := ThemeDB.fallback_font
	var head := Vector2(0, -136)
	match bandit.state:
		Bandit.State.NOTICE:
			var p := bandit.get_notice_progress()
			draw_string(font, head + Vector2(-5, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.2, 0.4 + 0.6 * p))
			draw_arc(head + Vector2(0, -8), 16.0, -PI / 2.0, -PI / 2.0 + TAU * p, 20, Color(1.0, 0.85, 0.2, 0.9), 2.0)
		Bandit.State.SEARCH:
			draw_string(font, head + Vector2(-5, 0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.85, 1.0, 0.9))
		Bandit.State.ATTACK:
			_draw_swing()
		Bandit.State.RETREAT:
			var t := bandit.get_attack_progress()
			if t > 0.0:
				draw_arc(Vector2(0, -54), 20.0 + 18.0 * (1.0 - t), 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.9), 2.0)
	if bandit.taunt_timer > 0.0:
		var text := Bandit.TAUNT_TEXT
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var box := Rect2(Vector2(-size.x * 0.5 - 6.0, -176.0), size + Vector2(12.0, 8.0))
		var a := clampf(bandit.taunt_timer / 0.4, 0.0, 1.0)
		draw_rect(box, Color(0, 0, 0, 0.7 * a), true)
		draw_rect(box, Color(1.0, 0.42, 0.0, 0.9 * a), false, 1.5)
		draw_string(font, box.position + Vector2(6.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))


## Ground wedge showing where the swing will land: thin and red while winding up (fills as the tell
## progresses), bright slash while active.
func _draw_swing() -> void:
	var dir := bandit._atk_dir
	var reach: float = float(bandit.profile.attack_reach)
	var half := deg_to_rad(float(bandit.profile.attack_arc_deg) * 0.5)
	var origin := Vector2(0, -14)
	var a0 := dir.angle() - half
	var a1 := dir.angle() + half
	var tell := bandit.get_attack_progress()
	if tell > 0.0:
		draw_arc(origin, reach, a0, a1, 16, Color(TELL_COLOR, 0.25 + 0.6 * tell), 2.0)
		draw_line(origin, origin + dir.rotated(-half) * reach * tell, Color(TELL_COLOR, 0.6), 1.5)
		draw_line(origin, origin + dir.rotated(half) * reach * tell, Color(TELL_COLOR, 0.6), 1.5)
	elif bandit.atk_phase in [Bandit.AtkPhase.ACTIVE1, Bandit.AtkPhase.ACTIVE2]:
		draw_arc(origin, reach, a0, a1, 16, SLASH_COLOR, 6.0)
