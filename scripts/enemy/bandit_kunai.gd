class_name BanditKunai
extends Node2D
## Thrown kunai. Originally the Bandit's ranged attack only; owner 2026-10-25 ("10x kunai ... D-pad")
## reuses this same node for the PLAYER's held-item kunai throw (see PlayerController._use_item), so
## the class is now shared by both sides -- the name stays for git-history continuity, not because
## it is bandit-only any more. Flies straight along the aim direction chosen when the throw's aim
## froze, stops on walls, and hands a landed hit to `take_hit` (so jump/dodge evade it and a timed
## Substitution swallows it). Uses the shared production black kunai asset.
##
## Two targeting modes:
##  - `target` set (bandit -> player): hits ONLY that node, exactly as before.
##  - `target` null and `hit_group` set (player -> any enemy): each step re-picks the nearest living
##    node currently in `hit_group` and runs the same segment-distance test against it. This is the
##    generic case a thrown item needs (the player has no single locked enemy to aim a throw at).

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
var hit_group: String = ""  ## used only when target == null; see class doc above
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


## The node currently being checked against: the fixed `target` if still valid, else the nearest
## valid node in `hit_group` (re-picked every step, since nothing freezes it like a bandit's throw does).
func _resolve_victim() -> Node2D:
	if target != null and is_instance_valid(target):
		return target
	if hit_group == "" or not is_inside_tree():
		return null
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(hit_group):
		if n is Node2D and is_instance_valid(n):
			var d := (n as Node2D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


## One simulation step (public so tests can drive it deterministically).
func step(delta: float) -> void:
	if hit_result != "":
		return
	var a := global_position
	var b := a + dir * speed * delta
	var victim := _resolve_victim()
	if victim != null:
		var seg := b - a
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((victim.global_position - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (a + seg * t).distance_to(victim.global_position) <= HIT_RADIUS:
			global_position = a + seg * t
			var who: Node2D = thrower if (thrower != null and is_instance_valid(thrower)) else null
			if victim.has_method("take_hit") and bool(victim.call("take_hit", damage, dir, 120.0, who)):
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
