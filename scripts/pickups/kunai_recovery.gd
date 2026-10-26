class_name KunaiRecovery
extends Node2D
## Shared one-shot surface / miss recovery. Uses approved art, rigid motion and synthesized metal clinks.
const STICK_TIME := 0.4
const FALL_TIME := 0.30
const BOUNCE_TIME := 0.48
const MAX_DROPS := 64
const LIFT := Vector2(0,-14)
static var _sound: AudioStreamWAV
var age := 0.0
var surface := false
var recoverable := true
var origin := Vector2.ZERO
var landing := Vector2.ZERO
var aim := Vector2.RIGHT
var initial_lift := -44.0
var finished := false
var clinks := 0
var pickup: HealthGourd
var body: Sprite2D
var _audio: AudioStreamPlayer2D

static func wall_hit(node: Node2D, a: Vector2, b: Vector2, who: Node2D = null) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(a+LIFT,b+LIFT)
	var excludes: Array[RID] = []
	for group: String in ["player","enemy"]:
		for actor in node.get_tree().get_nodes_in_group(group):
			if actor is CollisionObject2D: excludes.append(actor.get_rid())
	if is_instance_valid(who) and who is CollisionObject2D: excludes.append(who.get_rid())
	if is_instance_valid(who) and who is PhysicsBody2D:
		for passable in (who as PhysicsBody2D).get_collision_exceptions(): excludes.append(passable.get_rid())  # e.g. the shrine mound while the thrower stands on the platform
	query.collision_mask=1  # world walls only: player-only walls (the platform rim) never stop a kunai
	query.exclude=excludes
	return node.get_world_2d().direct_space_state.intersect_ray(query)

static func clear_ground(parent: Node2D, point: Vector2) -> bool:
	if parent.has_method("get_bounds") and not parent.call("get_bounds").grow(-30).has_point(point):
		return false
	var shape := RectangleShape2D.new()
	shape.size=WorldScale.FOOTPRINT
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,point+Vector2(0,-WorldScale.FOOTPRINT.y*0.5))
	for hit in parent.get_world_2d().direct_space_state.intersect_shape(query,32):
		if hit.collider is StaticBody2D: return false
	var nav: Variant = parent.get("nav")
	if nav is ArenaNav:
		if not nav.is_walkable(point): return false
		var player := parent.get_tree().get_first_node_in_group("player") as Node2D
		if player!=null and nav.find_path(player.global_position,point).is_empty(): return false
	return true

static func start(parent: Node2D, at: Vector2, direction: Vector2, lift: float, normal := Vector2.ZERO) -> KunaiRecovery:
	var recovery := KunaiRecovery.new()
	recovery.origin=at
	recovery.landing=at
	recovery.aim=direction
	recovery.initial_lift=lift
	recovery.surface=normal!=Vector2.ZERO
	recovery.recoverable=false
	if recovery.surface:
		# Search ONLY the impact side, close to the surface; never drop on the far side of a wall.
		for distance: float in [32.0,48.0,64.0,80.0,96.0]:
			var candidate := at+normal*distance
			if clear_ground(parent,candidate) and wall_hit(parent,at+normal*2.0,candidate).is_empty():
				recovery.landing=candidate
				recovery.recoverable=true
				break
	else:
		recovery.recoverable=clear_ground(parent,at)
	parent.add_child(recovery)
	recovery.global_position=at
	return recovery

func _ready() -> void:
	add_to_group("kunai_recovery")
	z_index=5
	body=Sprite2D.new()
	body.texture=load("res://assets/weapons/kunai/black_kunai.png")
	body.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	body.rotation=aim.angle()
	body.position.y=initial_lift
	add_child(body)
	_audio=AudioStreamPlayer2D.new()
	_audio.stream=clink_sound()
	_audio.volume_db=-15
	add_child(_audio)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if finished: return
	age+=delta
	var t := age-(STICK_TIME if surface else 0.0)
	if t<0.0: return
	var u := clampf(t/FALL_TIME,0,1)
	global_position=origin.lerp(landing,u*0.55)
	body.position.y=roundf(initial_lift*(1-u*u)-3*u*u)
	body.rotation=aim.angle()+u*TAU
	body.scale=Vector2.ONE.lerp(Vector2(0.7,0.45),u)
	if t>=FALL_TIME:
		if clinks==0: _clink()
		var bounce := clampf((t-FALL_TIME)/BOUNCE_TIME,0,1)
		global_position=origin.lerp(landing,0.55+bounce*0.45)
		body.position.y=-3+roundf(-14*sin(PI*bounce/0.6) if bounce<0.6 else -5*sin(PI*(bounce-0.6)/0.4))
		body.rotation=aim.angle()+TAU+sin(bounce*PI)*2.2+bounce*0.35
		if bounce>=0.6 and clinks==1: _clink()
		if bounce>=1.0: _settle()

func _clink() -> void:
	clinks+=1
	_audio.volume_db=-15 if clinks==1 else -23
	_audio.pitch_scale=1.0 if clinks==1 else 1.16
	if DisplayServer.get_name()!="headless": _audio.play()

func _settle() -> void:
	finished=true
	if recoverable and clear_ground(get_parent(),landing):
		var drops := get_tree().get_nodes_in_group("spent_kunai_pickup").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
		while drops.size()>=MAX_DROPS:
			var oldest: Node=drops.pop_front()
			oldest.queue_free()
		pickup=HealthGourd.new()
		pickup.kind="kunai"
		pickup.grounded=true
		pickup.respawns=false
		pickup.resting_rotation=aim.angle()+0.35
		get_parent().add_child(pickup)
		pickup.global_position=landing
		pickup.add_to_group("spent_kunai_pickup")
	queue_free()

static func clink_sound() -> AudioStreamWAV:
	if _sound!=null: return _sound
	var bytes := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed=51701
	for i in 4410:
		var t := float(i)/22050.0
		var sample := (sin(TAU*3100*t)*0.45+sin(TAU*4730*t)*0.27+sin(TAU*6820*t)*0.13+rng.randf_range(-0.12,0.12))*exp(-t*42.0)
		bytes.append(clampi(int(sample*90+128),0,255))
	_sound=AudioStreamWAV.new()
	_sound.format=AudioStreamWAV.FORMAT_8_BITS
	_sound.mix_rate=22050
	_sound.data=bytes
	return _sound
