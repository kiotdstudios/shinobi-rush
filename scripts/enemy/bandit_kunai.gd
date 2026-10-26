class_name BanditKunai
extends Node2D
## Thrown kunai fired by the Bandit's ranged attack. Flies straight along the aim direction chosen when
## the throw's aim froze, stops on walls, and hands a landed hit to `Player.take_hit` (so jump / dodge
## evade it and a timed Substitution swallows it). Uses the shared production black kunai asset.

const SPEED := 520.0
const MAX_RANGE := 560.0
const HIT_RADIUS := 22.0
const DRAW_LIFT := Vector2(0, -30)  ## drawn at hand height, travels along the ground plane
const TEXTURE := preload("res://assets/weapons/kunai/black_kunai.png")

var dir: Vector2 = Vector2.RIGHT
var speed: float = SPEED
var damage: float = 6.0
var thrower: Node2D = null
var target: Node2D = null
var travelled: float = 0.0
var _passed_target := false
var hit_result: String = ""  ## "", "hit", "evaded", "wall", "range" -- read by tests


static func spawn(parent: Node, from: Vector2, aim: Vector2, who: Node2D, tgt: Node2D, dmg: float = 6.0, spd: float = SPEED) -> BanditKunai:
	if parent == null:
		return null
	var kn := BanditKunai.new()
	kn.name = "BanditKunai"
	kn.dir = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	kn.speed = spd
	kn.damage = dmg
	kn.thrower = who
	kn.target = tgt
	parent.add_child(kn)
	kn.global_position = from
	kn.z_index = 5
	return kn


func _ready() -> void:
	var body := Sprite2D.new()
	body.name = "BlackKunai"
	body.texture = TEXTURE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = DRAW_LIFT
	body.offset = Vector2(0, 1)  # texture blade axis is at y=31 on its 64px canvas
	body.rotation = dir.angle()  # source blade points +X; fixed throw aim drives every heading
	add_child(body)


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step (public so tests can drive it deterministically).
func step(delta: float) -> void:
	if hit_result not in ["","evaded"]: return
	var a := global_position
	var length := minf(speed*delta,maxf(MAX_RANGE-travelled,0.0))
	var b := a+dir*length
	var seg := b-a
	var wall := KunaiRecovery.wall_hit(self,a,b,thrower)
	var wall_t := 2.0 if wall.is_empty() or length<0.001 else a.distance_to(wall.position-KunaiRecovery.LIFT)/length
	if not _passed_target and is_instance_valid(target):
		var t := clampf((target.global_position-a).dot(seg)/maxf(seg.length_squared(),0.0001),0,1)
		if (a+seg*t).distance_to(target.global_position)<=HIT_RADIUS and t<wall_t:
			var who: Node2D = thrower if is_instance_valid(thrower) else null
			if target.has_method("take_hit") and bool(target.call("take_hit",damage,dir,120.0,who)):
				global_position=a+seg*t
				hit_result="hit"
				queue_free()
				return
			# Dodge/jump/substitution remains unchanged; the missed blade continues without retesting this target.
			_passed_target=true
			hit_result="evaded"
	if not wall.is_empty():
		global_position=wall.position-KunaiRecovery.LIFT
		hit_result="wall"
		KunaiRecovery.start(get_parent(),global_position,dir,DRAW_LIFT.y,wall.normal)
		queue_free()
		return
	global_position=b
	travelled+=length
	if travelled>=MAX_RANGE-0.01:
		hit_result="range"
		KunaiRecovery.start(get_parent(),global_position,dir,DRAW_LIFT.y)
		queue_free()
