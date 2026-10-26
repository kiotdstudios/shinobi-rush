class_name EvadeStreakFx
extends AnimatedSprite2D
## Shared presentation only. Actor movement/timers/collisions remain authoritative.
## The three stationary afterimages are a bounded ring, never extrapolated path samples.
const FRAMES := 6
const FPS := 30.0
const CHEST := Vector2(0, -48)
const MAX_GHOSTS := 3
const GHOST_LIFE := 0.13
const MATERIAL := preload("res://assets/vfx/body_flicker/premium_silhouette.gdshader")
static var _frames: SpriteFrames
static var legacy_preview := false  ## isolated comparison scene only; normal game always false
var legacy := false
var actor: SpriteActor
var subject: CharacterBody2D
var heading := Vector2.RIGHT
var duration := 0.3
var travel_time := 0.2
var age := 0.0
var tail := 0.0
var active := true
var arrived := false
var _arrival_age := -1.0
var cancelled := false
var phase := "launch"
var sample_positions: Array[Vector2] = []
var last_position := Vector2.ZERO
var ghosts: Array[Sprite2D] = []
var ghost_ages: Array[float] = []
var _next_ghost := 0
var _sample_clock := 0.0
var _last_sample := Vector2.ZERO
var _ground: Array[AnimatedSprite2D] = []
var _highlight: Sprite2D
var _smear: Sprite2D
var _start_count := 0
var _body_source := ""
var _is_hop := false

static func spawn(parent: Node2D, dir: Vector2) -> EvadeStreakFx:
	if not parent is CharacterBody2D or not parent.is_inside_tree():return null
	for child in parent.get_children():
		if child is EvadeStreakFx:
			if child.active and child._is_acting():return child  # presentation re-entry never starts another gameplay dodge
			child.finish(true)
	var fx := EvadeStreakFx.new()
	fx.name = "EvadeStreakFx"
	fx.subject = parent
	fx.legacy = legacy_preview
	fx.heading = dir.normalized() if dir.length_squared()>0.001 else Vector2.DOWN
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.set_animation_loop("default",false)
		_frames.set_animation_speed("default",FPS)
		for i in FRAMES:_frames.add_frame("default",load("res://assets/vfx/ninja_evade/streak_%03d.png" % i))
	fx.sprite_frames = _frames
	fx.position = CHEST
	fx.rotation = fx.heading.angle()
	fx.z_index = 1
	parent.add_child(fx)
	return fx

func _ready() -> void:
	if subject is PlayerController:
		actor = subject.visual.actor
		duration = subject.flicker_duration
		travel_time = subject.flicker_burst_time
		_start_count = subject.flicker_count
	else:
		_is_hop = subject.flicker_hopping
		actor = (subject.visual as BanditVisual).actor
		_start_count = subject.flicker_count if _is_hop else subject.evade_count
		duration = float(subject.profile.flicker_hop_time) if subject.flicker_hopping else subject.evade_duration
		travel_time = duration
	duration = maxf(duration,0.001)
	travel_time = clampf(travel_time,0.001,duration)
	if legacy:
		play("default")
		return
	last_position = subject.global_position
	_last_sample = last_position
	for i in MAX_GHOSTS:
		ghosts.append(_new_silhouette(false))
		ghost_ages.append(GHOST_LIFE)
	_highlight = _new_silhouette(false)
	_highlight.material.set_shader_parameter("whiten",1.0)
	_highlight.material.set_shader_parameter("flash",1.0)
	_smear = _new_silhouette(true)
	_smear.modulate.a=0.28
	for kind in ["skid_a","ring_a"]:
		var puff := AnimatedSprite2D.new()
		puff.top_level = true
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		puff.sprite_frames = SpriteFrames.new()
		puff.sprite_frames.set_animation_loop("default",false)
		puff.sprite_frames.set_animation_speed("default",32.0)
		for texture in DustPuff.frames_for(kind):puff.sprite_frames.add_frame("default",texture)
		puff.visible = false
		add_child(puff)
		_ground.append(puff)
	_play_ground(0,subject.global_position)
	_pose(0.0)
	_snapshot(_highlight)
	_highlight.modulate.a = 0.65
	var streak_material := ShaderMaterial.new()
	streak_material.shader = MATERIAL
	streak_material.set_shader_parameter("streak",true)
	material=streak_material
	self_modulate = Color(0.82,0.9,1.0,0.0)
	play("default")

func _new_silhouette(smear: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.top_level = true
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = MATERIAL
	mat.set_shader_parameter("smear",smear)
	mat.set_shader_parameter("heading",heading)
	sprite.material = mat
	sprite.visible = false
	add_child(sprite)
	return sprite

func _snapshot(sprite: Sprite2D) -> void:
	if not is_instance_valid(actor) or actor.sprite.sprite_frames == null:return
	sprite.texture = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation,actor.sprite.frame)
	sprite.global_transform = actor.sprite.global_transform
	sprite.global_position=sprite.global_position.round()
	sprite.offset = actor.sprite.offset
	sprite.visible = true

func _play_ground(index: int, pos: Vector2) -> void:
	var puff := _ground[index]
	if puff.sprite_frames.get_frame_count("default")==0:return
	puff.global_position = pos.round()
	puff.rotation = 0.0
	puff.scale = Vector2(0.65,0.32) if index==0 else Vector2(0.52,0.26)
	puff.offset.y = -puff.sprite_frames.get_frame_texture("default",0).get_height()*0.4
	puff.modulate = Color(0.68,0.76,0.79,0.6)
	puff.visible = true
	puff.play("default")

func _is_acting() -> bool:
	if not is_instance_valid(subject):return false
	if subject is PlayerController:return subject.state==PlayerController.State.DODGE and subject.flicker_count==_start_count
	return (subject.flicker_hopping and subject.flicker_count==_start_count) if _is_hop else (subject.state==Bandit.State.EVADE and subject.evade_count==_start_count)

func _elapsed() -> float:
	if subject is PlayerController:return maxf(0.0,subject._action_duration-subject._action_timer)
	return maxf(0.0,duration-(subject._retreat_timer if _is_hop else subject._evade_timer))

## Authored poses selected at actual action progress; no actor scale or collider changes.
func _pose(elapsed: float) -> void:
	if not is_instance_valid(actor) or actor.set_ref==null:return
	var t := elapsed/duration
	phase = "launch" if t<0.12 else ("burst" if t<0.4 else ("travel" if elapsed<travel_time else ("arrival" if t<0.9 else "recovery")))
	if arrived:phase="arrival" if elapsed-_arrival_age<0.07 else "recovery"
	var set_ref := actor.set_ref
	var dir := SpriteSet.dir_name(heading)
	if set_ref.animations.has("dodge"):
		_body_source="dodge"
		var p := 0.0
		if t<0.12:p=lerpf(0.0,0.16,t/0.12)
		elif elapsed<travel_time:p=lerpf(0.25,0.55,clampf((elapsed-duration*0.12)/maxf(travel_time-duration*0.12,0.001),0.0,1.0))
		else:p=lerpf(0.58,0.99,clampf((elapsed-travel_time)/maxf(duration-travel_time,0.001),0.0,1.0))
		if arrived:p=lerpf(0.58,0.99,clampf((elapsed-_arrival_age)/maxf(duration-_arrival_age,0.001),0.0,1.0))
		actor.show_animation_at(set_ref,"dodge",dir,p)
	else:
		# Bandit keeps his own scarf/anatomy: authored bent-knee run -> arms-back sprint -> run settle.
		_body_source="sprint"
		var aid := "run" if t<0.12 or t>0.85 else "sprint"
		if not set_ref.animations.has(aid):aid=PlayerVisual.pick_animation(set_ref,true,true)
		if aid.is_empty():return
		actor.show_animation_at(set_ref,aid,dir,0.25 if t<0.12 else (0.68 if t>0.85 else 0.3+0.35*t))
	actor.visible=true

func _process(delta: float) -> void:
	if legacy:
		age+=delta
		if age>=0.2:queue_free()
		return
	if not is_instance_valid(subject) or not is_instance_valid(actor):queue_free();return
	if subject._hitstop_timer>0.0:return
	_sample_clock+=delta
	if active:
		if not _is_acting():
			var completed := _elapsed()>=duration-0.04
			finish(not completed)
		else:
			age=_elapsed()
			_pose(age)
			var distance := subject.global_position.distance_to(last_position)
			# Never bridge a substitution/teleport. Only actual continuous displacement produces ghosts.
			if distance>maxf(90.0,subject.velocity.length()*maxf(delta,0.001)*2.5):
				finish(true)
				return
			elif age>=duration*0.1 and age<=travel_time and subject.global_position.distance_to(_last_sample)>=16.0 and _sample_clock>=0.027:
				_snapshot(ghosts[_next_ghost])
				ghost_ages[_next_ghost]=0.0
				_next_ghost=(_next_ghost+1)%MAX_GHOSTS
				_last_sample=subject.global_position
				sample_positions.append(_last_sample)
				if sample_positions.size()>16:sample_positions.pop_front()
				_sample_clock=0.0
				_snapshot(_smear)
				_smear.modulate.a=0.28
			if not arrived and (age>=travel_time or (age>duration*0.15 and distance<0.1 and delta>0.0)):
				_arrive()
			last_position=subject.global_position
			_highlight.visible=age<0.025 or (arrived and age-_arrival_age>=0.0 and age-_arrival_age<0.018)
			if _highlight.visible:_snapshot(_highlight)
			_smear.visible=age>0.03 and age<travel_time and not arrived and distance>0.1
			if arrived and age>=_arrival_age and age<_arrival_age+0.045:
				_smear.visible=true
				_smear.material.set_shader_parameter("spread",maxf(0.0,1.0-(age-_arrival_age)/0.045))
			else:_smear.material.set_shader_parameter("spread",1.0)
			if _smear.visible:_snapshot(_smear)
			self_modulate.a=0.55 if _smear.visible else 0.0
	else:
		tail+=delta
		self_modulate.a=0.0
		_smear.visible=false
		_highlight.visible=false
		if tail>0.14:queue_free()
	for i in MAX_GHOSTS:
		ghost_ages[i]+=delta
		ghosts[i].modulate.a=0.42*pow(maxf(0.0,1.0-ghost_ages[i]/GHOST_LIFE),1.5)
		ghosts[i].visible=ghost_ages[i]<GHOST_LIFE

func _arrive() -> void:
	if arrived:return
	arrived=true
	_arrival_age=age
	_snapshot(_smear)
	_play_ground(1,subject.global_position)

func finish(interrupted: bool=false) -> void:
	if not active and not interrupted:return
	active=false
	cancelled=interrupted
	if not interrupted and is_instance_valid(subject):_arrive()
	if interrupted:
		_smear.visible=false
		_highlight.visible=false
		for ghost in ghosts:ghost.visible=false
		for i in MAX_GHOSTS:ghost_ages[i]=GHOST_LIFE
		for puff in _ground:puff.visible=false
	self_modulate.a=0.0

func debug_state() -> Dictionary:
	var live := 0
	for ghost in ghosts:
		if ghost.visible:live+=1
	return {"phase":phase,"active":active,"arrived":arrived,"cancelled":cancelled,"ghosts":live,"pool":ghosts.size(),"samples":sample_positions,"age":age,"duration":duration,"body_source":_body_source,"heading":heading,"direction":actor.dir if is_instance_valid(actor) else ""}
