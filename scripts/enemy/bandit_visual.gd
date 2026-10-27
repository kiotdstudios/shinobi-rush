class_name BanditVisual
extends Node2D
## Explicit enemy-only binding of Codex's 128px red-scarf bandit art.
## Missing art/death retain the procedural fallback until dedicated action art is available.

const ART_PATH := "res://assets/characters/bandit/bandit_128.art.json"
static var _art_set: SpriteSet
static var _art_checked := false

@export_enum("auto", "run", "sprint") var approach_animation: String = "auto"
var streak: EvadeStreakFx
var _last_evade := 0
var _last_flicker := 0
var locomotion := LocomotionTransition.new()
var actor: SpriteActor
var weapon_layer: KunaiWeaponVisual

const CLOTH := Color("#5a3a2a")
const LIMB := Color("#3a2a1a")
const SKIN := Color("#8a4a3a")
const DEATH_CLIP := 0.667
const DEATH_FADE_DELAY := 1.6
const DEAD_TINT := Color("#555555")
const MOVING_STATES := [Bandit.State.APPROACH, Bandit.State.EVADE, Bandit.State.PATROL, Bandit.State.SEARCH, Bandit.State.RETURN, Bandit.State.REPOSITION]
const SLASH_COLOR := Color(1.0, 0.85, 0.6, 0.9)
const TELL_COLOR := Color(1.0, 0.2, 0.15)

var bandit: Bandit
var crew_applied := -999

## Recolours only the art's crimson scarf/headband (hue ~0.93-0.97, well apart from the skin and leather at ~0.02-0.07)
## to the crew hue, keeping its painted shading.
const CREW_SHADER := """
shader_type canvas_item;
uniform float target_hue = 0.46;
uniform float hue_lo = 0.90;
uniform float hue_hi = 0.995;
uniform float min_sat = 0.35;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec3 hsv = rgb2hsv(COLOR.rgb);
	if (hsv.x >= hue_lo && hsv.x <= hue_hi && hsv.y >= min_sat) {
		COLOR.rgb = hsv2rgb(vec3(target_hue, hsv.y, hsv.z));
	}
}
"""
static var _crew_shader: Shader


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
	_process(0.0)


func _process(delta: float) -> void:
	if bandit == null or actor == null:
		return
	if crew_applied != bandit.crew_id:
		apply_crew()
	var art_ok := _art_set != null and _art_set.is_valid()
	var dead := bandit.state == Bandit.State.DEAD
	var damage_clip := ""
	var damage_progress := 0.0
	if art_ok and dead and _art_set.animations.has("death"):
		damage_clip = "death"
		damage_progress = clampf(bandit._death_time / DEATH_CLIP, 0.0, 1.0)  # holds the prone last frame
	elif art_ok and bandit.state == Bandit.State.HIT_REACT and _art_set.animations.has(bandit.react_kind):
		damage_clip = bandit.react_kind
		damage_progress = bandit.react_progress()
	actor.visible = art_ok and (not dead or damage_clip != "")
	if not actor.visible:weapon_layer.visible=false
	if damage_clip != "":
		locomotion.interrupt()
		weapon_layer.visible = false
		actor.show_animation_at(_art_set, damage_clip, SpriteSet.dir_name(bandit.facing8), damage_progress)
		var dt := Color.WHITE
		if bandit._hit_flash_timer > 0.0:
			dt = Bandit.HIT_FLASH
		elif dead and bandit._death_time > DEATH_CLIP + DEATH_FADE_DELAY:
			dt.a = clampf(1.0 - (bandit._death_time - DEATH_CLIP - DEATH_FADE_DELAY) / 0.8, 0.0, 1.0)
		actor.modulate = dt
		# Squash on impact, settles over the first quarter of the clip.
		var punch := clampf(1.0 - damage_progress * 4.0, 0.0, 1.0) if not dead else 0.0
		actor.scale = Vector2(1.0 + 0.12 * punch, 1.0 - 0.12 * punch)
	elif actor.visible:
		actor.scale = Vector2.ONE
		var combat_pose := _show_kunai_pose()
		var throw_progress := bandit.get_throw_progress()
		var turning := bandit._turn_pause > 0.0 and bandit.state in MOVING_STATES
		var moving := bandit.state in MOVING_STATES and (bandit.velocity.length_squared() > 1.0 or turning)
		var transitioning := false
		var can_transition := bandit.state in [Bandit.State.IDLE, Bandit.State.PATROL, Bandit.State.APPROACH, Bandit.State.SEARCH, Bandit.State.RETURN, Bandit.State.REPOSITION]
		if combat_pose or throw_progress >= 0.0 or bandit.state in [Bandit.State.HIT_REACT, Bandit.State.EVADE, Bandit.State.RETREAT]:
			locomotion.interrupt()
		# Knockback is not a running cycle. Keep the struck pose through hurt/hitstop.
		if not combat_pose and (bandit.state != Bandit.State.HIT_REACT or actor.set_ref == null):
			if throw_progress >= 0.0 and _art_set.animations.has("throw"):
				actor.show_animation_at(_art_set, "throw", SpriteSet.dir_name(bandit.facing8), throw_progress)
			else:
				var action := "idle"
				if moving:
					action = ("sprint" if bandit.is_sprinting else "run") if approach_animation == "auto" else approach_animation
				if can_transition:
					locomotion.update(delta, moving, bandit.facing8 if turning else bandit.velocity, bandit.facing8, action == "sprint")
				else:
					locomotion.interrupt()
				# Preserve gait phase across octant and run/sprint changes; idle still starts deliberately.
				var preserve := moving and actor.anim_id in ["run", "sprint"]
				var phase := 0.0
				if preserve:
					phase = (actor.sprite.frame + actor.sprite.frame_progress) / float(actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation))
				transitioning = locomotion.show(actor, _art_set)
				if not transitioning:
					actor.show_animation(_art_set, action, SpriteSet.dir_name(bandit.facing8))
				if locomotion.completed and moving and not transitioning:
					actor.sprite.set_frame_and_progress(mini(3, actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)-1), 0.0)
				elif preserve and not transitioning:
					var frame := phase * actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
					actor.sprite.set_frame_and_progress(int(frame), frame - floorf(frame))
		# Slow walking states reuse the run cycle at a matching cadence (no dedicated walk art yet).
		var cadence := 1.0
		if moving and not bandit.is_sprinting and bandit.state != Bandit.State.EVADE:
			cadence = clampf(bandit.velocity.length() / bandit.move_speed, 0.4, 1.0)
		if combat_pose or throw_progress>=0.0 or transitioning:actor.sprite.pause()
		else:actor.set_playback(cadence, bandit._hitstop_timer > 0.0 or bandit.state == Bandit.State.HIT_REACT)
		var tint := Color.WHITE
		var tell := bandit.get_attack_progress()
		if bandit._hit_flash_timer > 0.0:
			tint = Bandit.HIT_FLASH
		elif bandit.state == Bandit.State.ATTACK and tell > 0.0:
			tint = Color(1.0, 1.0 - 0.55 * tell, 1.0 - 0.55 * tell)  # reddens as the swing nears
		elif bandit.state == Bandit.State.RETREAT and tell > 0.0:
			tint = Color(1.0 - 0.3 * tell, 0.9, 1.0)  # cold flash before the flicker
		actor.modulate = tint
		weapon_layer.modulate=tint
	if bandit.evade_count != _last_evade:
		_last_evade = bandit.evade_count
		streak = EvadeStreakFx.spawn(bandit,bandit.velocity)
	if bandit.flicker_count != _last_flicker:
		_last_flicker = bandit.flicker_count
		streak = EvadeStreakFx.spawn(bandit,bandit._retreat_hop_velocity)
	if is_instance_valid(streak) and bandit.state in [Bandit.State.HIT_REACT,Bandit.State.DEAD]:
		streak.finish(true)
		streak.visible=false
	queue_redraw()


func apply_crew() -> void:
	crew_applied = bandit.crew_id
	var hue := float(Bandit.crew_info(bandit.crew_id).hue)
	if hue < 0.0:
		actor.sprite.material = null
		return
	if _crew_shader == null:
		_crew_shader = Shader.new()
		_crew_shader.code = CREW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _crew_shader
	mat.set_shader_parameter("target_hue", hue)
	actor.sprite.material = mat


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


## Blue chakra-charge aura: pulsing ring at his feet and rising sparks.
func _draw_chakra_aura() -> void:
	var t := bandit.clock
	var pulse := 0.5 + 0.5 * sin(t * 9.0)
	draw_arc(Vector2(0, -6), 20.0 + 4.0 * pulse, 0.0, TAU, 28, Color(0.35, 0.75, 1.0, 0.55 + 0.3 * pulse), 2.0)
	draw_circle(Vector2(0, -6), 14.0, Color(0.3, 0.6, 1.0, 0.12 + 0.1 * pulse))
	for i in 5:
		var ph := fmod(t * 1.3 + float(i) * 0.2, 1.0)
		draw_circle(Vector2(sin(float(i) * 2.4) * 12.0, -6.0 - ph * 46.0), 2.0 * (1.0 - ph) + 0.5, Color(0.6, 0.9, 1.0, 1.0 - ph))


func _draw_hp_and_label(top_y: float = -78.0) -> void:
	var font := ThemeDB.fallback_font
	if bandit.is_charging_chakra and bandit.state != Bandit.State.DEAD:
		_draw_chakra_aura()
	var block := UnitBars.size_for(bandit.max_substitutions)
	var y0 := top_y - block.y + 6.0  ## bars sit on the old HP-bar line, growing upward over the head
	var crew := Bandit.crew_info(bandit.crew_id)
	draw_string(font, Vector2(-30.0, y0 - 4.0), "%s L%d (%s)" % [String(crew.name).to_upper(), bandit.intelligence_level, bandit.get_state_name()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(crew.color as Color, 0.85))
	if bandit.state == Bandit.State.DEAD:
		return
	var frac := clampf(bandit.hp / bandit.max_hp, 0.0, 1.0)
	var cfrac := clampf(bandit.chakra / maxf(bandit.max_chakra, 0.001), 0.0, 1.0)
	UnitBars.draw(self, Vector2(-block.x * 0.5, y0), frac, cfrac, bandit.substitutions, bandit.max_substitutions, bandit.sub_use_age)


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
	if bandit.drinking != "":
		var icon := HealthGourd.icon(bandit.drinking)
		if icon != null:
			draw_set_transform(head + Vector2(18, 10), -0.6, Vector2.ONE * 0.45)
			draw_texture(icon, -icon.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO)
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
