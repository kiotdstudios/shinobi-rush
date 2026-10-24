class_name PlayerKunai
extends Node2D
## A kunai the player throws from the inventory. Flies straight, hits the first "enemy" it passes close to (light
## damage, small knockback), stops on walls, vanishes at MAX_RANGE. Same black kunai art as the Bandit's.

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
	if hit_result != "":
		return
	var a := global_position
	var b := a + dir * SPEED * delta
	var seg := b - a
	var best: Node2D = null
	var best_t := 2.0
	if is_inside_tree():
		for e: Node in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D) or e == thrower or not e.has_method("take_damage"):
				continue
			var t := 0.0
			if seg.length_squared() > 0.0001:
				t = clampf(((e as Node2D).global_position - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
			if (a + seg * t).distance_to((e as Node2D).global_position) <= HIT_RADIUS and t < best_t:
				best = e as Node2D
				best_t = t
	if best != null:
		global_position = a + seg * best_t
		best.call("take_damage", DAMAGE, dir, KNOCKBACK, HITSTOP_MS)
		hit_target = best
		hit_result = "hit"
		queue_free()
		return
	if is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(a + Vector2(0, -14), b + Vector2(0, -14))
		var ex: Array[RID] = []
		if is_instance_valid(thrower) and thrower is CollisionObject2D:
			ex.append((thrower as CollisionObject2D).get_rid())
		q.exclude = ex
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			hit_result = "wall"
			queue_free()
			return
	global_position = b
	travelled += seg.length()
	if travelled >= MAX_RANGE:
		hit_result = "range"
		queue_free()
