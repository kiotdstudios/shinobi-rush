class_name PlayerKunai
extends Node2D
## A kunai the player throws from the inventory. Flies straight, hits the first "enemy" it passes close to (light
## damage, small knockback), embeds on surfaces and drops after misses; character hits consume it. Same black kunai art as the Bandit's.

const SPEED := 640.0
const MAX_RANGE := 520.0
const HIT_RADIUS := 24.0
const DAMAGE := 8.0
const KNOCKBACK := 140.0
const HITSTOP_MS := 40.0
const DRAW_LIFT := Vector2(0, -44)  ## hand height; travels along the ground plane
const TEXTURE := preload("res://assets/weapons/kunai/black_kunai.png")

var dir: Vector2 = Vector2.RIGHT
var thrower: Node2D = null
var travelled := 0.0
var hit_result := ""  ## "", "hit", "wall", "range" (read by tests)
var hit_target: Node2D = null


static func spawn(parent: Node, from: Vector2, aim: Vector2, who: Node2D) -> PlayerKunai:
	if parent == null:
		return null
	var kn := PlayerKunai.new()
	kn.dir = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	kn.thrower = who
	parent.add_child(kn)
	kn.global_position = from
	kn.z_index = 5
	return kn


func _ready() -> void:
	var body := Sprite2D.new()
	body.name = "Kunai"
	body.texture = TEXTURE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = DRAW_LIFT
	body.offset = Vector2(0, 1)
	body.rotation = dir.angle()
	add_child(body)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if hit_result != "": return
	var a := global_position
	var length := minf(SPEED*delta,maxf(MAX_RANGE-travelled,0.0))
	var b := a+dir*length
	var seg := b-a
	var wall := KunaiRecovery.wall_hit(self,a,b,thrower)
	var wall_t := 2.0 if wall.is_empty() or length<0.001 else a.distance_to(wall.position-KunaiRecovery.LIFT)/length
	var best: Node2D
	var best_t := 2.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D) or enemy==thrower or not enemy.has_method("take_damage"): continue
		var t := clampf((enemy.global_position-a).dot(seg)/maxf(seg.length_squared(),0.0001),0,1)
		if (a+seg*t).distance_to(enemy.global_position)<=HIT_RADIUS and t<best_t and t<wall_t:
			best=enemy
			best_t=t
	if best!=null:
		global_position=a+seg*best_t
		best.call("take_damage",DAMAGE,dir,KNOCKBACK,HITSTOP_MS)
		hit_target=best
		hit_result="hit"
		queue_free()
		return
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
