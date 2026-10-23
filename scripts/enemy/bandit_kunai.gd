class_name BanditKunai
extends Node2D
## Thrown kunai fired by the Bandit's ranged attack. Flies straight along the aim direction chosen when
## the throw's aim froze, stops on walls, and hands a landed hit to `Player.take_hit` (so jump / dodge
## evade it and a timed Substitution swallows it). The body is drawn procedurally for now.

const SPEED := 520.0
const MAX_RANGE := 560.0
const HIT_RADIUS := 22.0
const DRAW_LIFT := Vector2(0, -30)  ## drawn at hand height, travels along the ground plane

var dir: Vector2 = Vector2.RIGHT
var speed: float = SPEED
var damage: float = 6.0
var thrower: Node2D = null
var target: Node2D = null
var travelled: float = 0.0
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


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step (public so tests can drive it deterministically).
func step(delta: float) -> void:
	if hit_result != "":
		return
	var a := global_position
	var b := a + dir * speed * delta
	if target != null and is_instance_valid(target):
		var seg := b - a
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((target.global_position - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (a + seg * t).distance_to(target.global_position) <= HIT_RADIUS:
			global_position = a + seg * t
			var who: Node2D = thrower if (thrower != null and is_instance_valid(thrower)) else null
			if target.has_method("take_hit") and bool(target.call("take_hit", damage, dir, 120.0, who)):
				hit_result = "hit"
			else:
				hit_result = "evaded"
			queue_free()
			return
	if is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(a + Vector2(0, -14), b + Vector2(0, -14))
		var ex: Array[RID] = []
		if is_instance_valid(thrower) and thrower is CollisionObject2D:
			ex.append((thrower as CollisionObject2D).get_rid())
		if is_instance_valid(target) and target is CollisionObject2D:
			ex.append((target as CollisionObject2D).get_rid())
		q.exclude = ex
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			hit_result = "wall"
			queue_free()
			return
	global_position = b
	travelled += (b - a).length()
	if travelled >= MAX_RANGE:
		hit_result = "range"
		queue_free()


func _draw() -> void:
	draw_set_transform(DRAW_LIFT, dir.angle(), Vector2.ONE)
	draw_circle(Vector2(0, 0), 1.0, Color(0, 0, 0, 0))
	draw_line(Vector2(-16, 0), Vector2(-4, 0), Color(0.82, 0.86, 0.9, 0.25), 2.0)  # motion streak
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -2.5), Vector2(10, 0), Vector2(-3, 2.5)]), Color(0.78, 0.82, 0.88))
	draw_line(Vector2(-3, 0), Vector2(8, 0), Color(1, 1, 1, 0.8), 1.0)
	draw_rect(Rect2(-9, -1.6, 6, 3.2), Color(0.72, 0.1, 0.1))
	draw_arc(Vector2(-11, 0), 2.6, 0.0, TAU, 10, Color(0.78, 0.82, 0.88), 1.2)
