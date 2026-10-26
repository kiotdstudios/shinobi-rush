class_name PaperTag
extends Node2D
## Thrown explosive item (owner 2026-10-25: "10x kunai, health gourd, chakra gourd, and paper tags").
## Brand new mechanic -- nothing like it existed before this order. Flies in a straight line like a
## kunai throw, stops on the first wall OR after FLIGHT_RANGE, then sits armed for FUSE_SECONDS before
## exploding: everything in `hit_group` within BLAST_RADIUS at that moment takes `damage`, once each.
## All art is procedural (a folded-paper square with a kanji-style ink mark, matching this project's
## "no art asset exists yet -- draw it" convention used elsewhere for placeholder-but-shipped visuals).

const FLIGHT_SPEED := 420.0
const FLIGHT_RANGE := 420.0
const FUSE_SECONDS := 1.0
const BLAST_RADIUS := 90.0
const TAG_SIZE := 16.0
const PAPER_COLOR := Color(0.95, 0.9, 0.78)
const INK_COLOR := Color(0.75, 0.15, 0.12)

var dir: Vector2 = Vector2.RIGHT
var damage: float = 18.0
var thrower: Node2D = null
var hit_group: String = "enemy"
var state: String = "flying"  ## "flying" -> "armed" -> "done"
var _travelled: float = 0.0
var _fuse_left: float = FUSE_SECONDS
var _clock: float = 0.0
var hit_count: int = 0  ## how many victims this explosion damaged -- read by tests


static func spawn(parent: Node, from: Vector2, aim: Vector2, who: Node2D, dmg: float = 18.0, group: String = "enemy") -> PaperTag:
	if parent == null:
		return null
	var tag := PaperTag.new()
	tag.name = "PaperTag"
	tag.dir = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	tag.damage = dmg
	tag.thrower = who
	tag.hit_group = group
	parent.add_child(tag)
	tag.global_position = from
	tag.z_index = 5
	return tag


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step (public so tests can drive it deterministically).
func step(delta: float) -> void:
	_clock += delta
	if state == "done":
		return
	if state == "flying":
		var a := global_position
		var b := a + dir * FLIGHT_SPEED * delta
		if is_inside_tree():
			var q := PhysicsRayQueryParameters2D.create(a, b)
			var ex: Array[RID] = []
			if is_instance_valid(thrower) and thrower is CollisionObject2D:
				ex.append((thrower as CollisionObject2D).get_rid())
			q.exclude = ex
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				global_position = hit.position
				state = "armed"
				queue_redraw()
				return
		global_position = b
		_travelled += (b - a).length()
		if _travelled >= FLIGHT_RANGE:
			state = "armed"
			queue_redraw()
		return
	# armed: sit still, fuse ticking down to detonation.
	_fuse_left = maxf(_fuse_left - delta, 0.0)
	queue_redraw()
	if _fuse_left <= 0.0:
		_explode()


func _explode() -> void:
	state = "done"
	hit_count = 0
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group(hit_group):
			if n is Node2D and is_instance_valid(n):
				var victim := n as Node2D
				if victim.global_position.distance_to(global_position) <= BLAST_RADIUS and victim.has_method("take_hit"):
					var away := (victim.global_position - global_position)
					away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
					if bool(victim.call("take_hit", damage, away, 200.0, thrower)):
						hit_count += 1
	queue_redraw()
	# A couple of frames to show the burst before freeing (tests advance `done_linger` manually).
	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_callback(queue_free)


## Progress 0..1 through the countdown while armed (for the fuse-glow draw); 0 while flying/done.
func fuse_progress() -> float:
	return clampf(1.0 - _fuse_left / FUSE_SECONDS, 0.0, 1.0) if state == "armed" else 0.0


func _draw() -> void:
	if state == "done":
		# Brief procedural burst: a bright ring + radial sparks, matching the project's additive-FX style.
		var a := 1.0
		draw_circle(Vector2.ZERO, BLAST_RADIUS * 0.3, Color(1.0, 0.75, 0.35, 0.35 * a))
		for i in 10:
			var ang := TAU * float(i) / 10.0
			draw_line(Vector2.ZERO, Vector2.from_angle(ang) * BLAST_RADIUS * 0.55, Color(1.0, 0.6, 0.2, 0.8 * a), 3.0)
		return
	# Folded paper square, slight diamond rotation so it reads against the iso floor; a dark ink mark.
	var half := TAG_SIZE * 0.5
	var pts := PackedVector2Array([Vector2(0, -half), Vector2(half, 0), Vector2(0, half), Vector2(-half, 0)])
	draw_colored_polygon(pts, PAPER_COLOR)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.3, 0.26, 0.2, 0.8), 1.0)
	draw_line(Vector2(0, -half * 0.5), Vector2(0, half * 0.5), INK_COLOR, 2.0)
	if state == "armed":
		# Fuse glow brightens as detonation nears.
		var glow := fuse_progress()
		draw_circle(Vector2.ZERO, half * (1.0 + glow), Color(1.0, 0.5, 0.2, 0.25 * glow))
