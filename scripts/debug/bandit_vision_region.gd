class_name BanditVisionRegion
extends RefCounted
## Debug only (Bandit vision overlay). The region in which the Level 1 Bandit's AI accepts the player as SEEN,
## as a polygon in world px, built from the AI's OWN numbers and the AI's OWN collision query.
##
## What `Bandit.can_see(target, use_cone)` accepts (scripts/enemy/bandit.gd, can_see + line_clear_to):
##   d = |target - position|
##   reach = profile.sight_range * (1.0 if use_cone else 1.35)      d must not exceed it
##   use_cone and d > profile.close_sense  ->  |facing8.angle_to(to)| must not exceed fov_deg / 2
##   a ray from position + EYE_OFFSET to target + EYE_OFFSET must hit nothing (own body and the player excluded,
##   default mask, bodies only)
## and `use_cone` is `not chasing`, chasing being NOTICE / APPROACH / THREATEN / ATTACK / REPOSITION / RETREAT.
## The accepted set is star-shaped around the Bandit (every point between the Bandit and an accepted point is
## accepted too), so it is described exactly by a radius per direction: min(range limit, first collider along the
## ray). This class samples that radius with the SAME ray query, then bisects between samples wherever a wall
## silhouette or corner sits so the polygon edge follows the true boundary to a fraction of a pixel.
##
## Mirrored from the AI (the AI does not expose them): CHASE_REACH_MULT and the chasing state list. Both are guarded:
## tests/test_bandit_vision_overlay.gd parses bandit.gd for them and compares the polygon with the live can_see.

## Mirror of the literal `1.35` in Bandit.can_see: the reach multiplier while chasing (no cone).
const CHASE_REACH_MULT := 1.35
## Mirror of the `chasing` list in Bandit._update_perception (look with range + line of sight only).
const CHASING_STATES: Array = [
	Bandit.State.NOTICE, Bandit.State.APPROACH, Bandit.State.THREATEN,
	Bandit.State.ATTACK, Bandit.State.REPOSITION, Bandit.State.RETREAT,
]
## States in which the AI does NOT evaluate sight at all (Bandit._physics_process returns before
## _update_perception). Both always continue to APPROACH (a chasing state), so the region shown is the chasing one.
const PAUSED_STATES: Array = [Bandit.State.EVADE, Bandit.State.HIT_REACT]

const FAR_STEP_DEG := 3.0  ## angular step of the base fan where the rays are long
const NEAR_STEP_DEG := 6.0  ## ... where they are short (the close-sense circle)
const NEAR_RADIUS := 300.0  ## rays up to this long use NEAR_STEP_DEG
const MAX_DEPTH := 8  ## bisection levels per interval (3 deg / 256 = 0.012 deg, 0.14 px at 700 px)
const FLAT_TOL := 0.3  ## px: a chord this close to the real surface is accepted as it is
const MAX_RAYS := 512  ## hard budget of ray queries per Bandit per rebuild (base fan + bisection); typical rebuilds use 110 to 300
const MIN_DT := 1.0e-4  ## rad: never bisect narrower than this
const DUP_EPS := 0.05  ## px: consecutive points closer than this are merged
const BOUNDARY_TOL := 1.0  ## px: see near_ai_boundary()

## Counts every rebuild; tests use it to prove that nothing is computed while the overlay is OFF.
static var compute_count: int = 0

var points := PackedVector2Array()  ## the polygon, ordered by angle around `origin` (empty if nothing can be seen)
var origin := Vector2.ZERO  ## Bandit.global_position
var facing := Vector2.DOWN  ## Bandit.facing8
var state: int = Bandit.State.PATROL
var use_cone := true  ## the AI's use_cone for this state
var paused := false  ## the AI does not evaluate sight in this state
var reach := 0.0  ## outer radius in use, px
var close_sense := 0.0
var fov_deg := 0.0
var half_angle := 0.0  ## rad
var rays_cast := 0
var capped := false  ## the bisection stopped early because MAX_RAYS was reached

var _dir := Vector2.DOWN
var _eye := Vector2.ZERO
var _space: PhysicsDirectSpaceState2D = null
var _q: PhysicsRayQueryParameters2D = null
var _pts := PackedVector2Array()
var _rays := 0


## One ray: angle `t` relative to the facing, radius `r` (first hit or the range limit), and what it hit.
class Sample:
	var t := 0.0
	var r := 0.0
	var pos := Vector2.ZERO  ## the polygon vertex: origin + direction * r (a player foot position the AI would accept)
	var hit := false
	var cid := 0
	var shape := 0
	var normal := Vector2.ZERO


static func is_chasing(st: int) -> bool:
	return CHASING_STATES.has(st)


static func is_paused(st: int) -> bool:
	return PAUSED_STATES.has(st)


## The AI's use_cone for a Bandit in state `st` (see the class comment for EVADE / HIT_REACT).
static func uses_cone(st: int) -> bool:
	return not CHASING_STATES.has(st) and not PAUSED_STATES.has(st)


## Region of `bandit` as it is right now. `player` is the node the AI excludes from its ray (first node of group "player").
static func compute(bandit: Bandit, player: Node = null, reach_mult: float = CHASE_REACH_MULT) -> BanditVisionRegion:
	compute_count += 1
	var r := BanditVisionRegion.new()
	r._build(bandit, player, reach_mult)
	return r


## Is `p` inside the drawn polygon?
func contains(p: Vector2) -> bool:
	if points.size() < 3:
		return false
	if p.distance_squared_to(origin) > reach * reach + 4.0:
		return false
	return Geometry2D.is_point_in_polygon(p, points)


## Runtime sync probe: two points on the facing ray, 4 px inside and 4 px outside the edge the polygon claims there, must
## be accepted / refused by the AI's own can_see. "" when they agree, else one exact line describing the disagreement.
## It re-checks the numbers the polygon was built from (reach, chase multiplier, eye offset, exclusions) every rebuild
## for three ray queries.
func sync_probe(bandit: Bandit) -> String:
	if _q == null or reach <= 0.0 or (use_cone and half_angle <= 0.0):
		return ""
	var r0 := _cast(0.0, reach).r
	if r0 < 12.0:
		return ""
	var inside := origin + _dir * (r0 - 4.0)
	var outside := origin + _dir * (r0 + 4.0)
	var in_ok := bandit.can_see(inside, use_cone)
	var out_ok := bandit.can_see(outside, use_cone)
	if in_ok and not out_ok:
		return ""
	return "facing ray r0=%.1f mode=%s reach=%.1f: can_see(r0-4)=%s (polygon says seen), can_see(r0+4)=%s (polygon says not seen)" % [
		r0, "cone" if use_cone else "no-cone", reach, str(in_ok), str(out_ok)]


## True if `p` is within `tol` px of the AI's own decision boundary: moving it by `tol` px in one of 16 directions changes
## what `bandit.can_see` answers. Pure can_see calls, so it needs no model of the AI. This is the stated tolerance band of the
## oracle: the polygon may only disagree with can_see inside it.
static func near_ai_boundary(bandit: Bandit, p: Vector2, cone: bool, tol: float = BOUNDARY_TOL) -> bool:
	var here := bandit.can_see(p, cone)
	for k in 16:
		var q := p + Vector2.from_angle(TAU * float(k) / 16.0) * tol
		if bandit.can_see(q, cone) != here:
			return true
	return false


# ------------------------------------------------------------------------------------------------ build
func _build(bandit: Bandit, player: Node, reach_mult: float) -> void:
	origin = bandit.global_position
	facing = bandit.facing8
	state = bandit.state
	use_cone = uses_cone(state)
	paused = is_paused(state)
	var prof: Dictionary = bandit.profile
	var sight: float = float(prof.get("sight_range", 0.0))
	fov_deg = float(prof.get("fov_deg", 0.0))
	close_sense = float(prof.get("close_sense", 0.0))
	half_angle = deg_to_rad(fov_deg * 0.5)
	reach = sight * (1.0 if use_cone else reach_mult)
	if reach <= 0.0 or not bandit.is_inside_tree():
		return
	_dir = facing.normalized() if facing.length_squared() > 0.0 else Vector2.DOWN
	_space = bandit.get_world_2d().direct_space_state
	_eye = origin + Bandit.EYE_OFFSET
	# Same query as Bandit.line_clear_to: default mask, bodies only, own body and the player excluded.
	_q = PhysicsRayQueryParameters2D.create(_eye, _eye)
	var excluded: Array[RID] = [bandit.get_rid()]
	if player is CollisionObject2D:
		excluded.append((player as CollisionObject2D).get_rid())
	_q.exclude = excluded

	# [t0, t1, radius limit] runs of constant limit: the whole circle, or (cone) close-sense circle / sector / circle.
	var segs: Array = []
	if use_cone and half_angle < PI:
		var near_r := minf(close_sense, reach)
		if half_angle <= 0.0:
			segs.append([-PI, PI, near_r])
		else:
			segs.append([-PI, -half_angle, near_r])
			segs.append([-half_angle, half_angle, reach])
			segs.append([half_angle, PI, near_r])
	else:
		segs.append([-PI, PI, reach])

	for seg: Array in segs:
		var t0: float = seg[0]
		var t1: float = seg[1]
		var rmax: float = seg[2]
		var step := deg_to_rad(FAR_STEP_DEG if rmax > NEAR_RADIUS else NEAR_STEP_DEG)
		var n := maxi(1, ceili((t1 - t0) / step - 1.0e-9))
		var prev := _cast(t0, rmax)
		_emit(prev)
		for k in range(1, n + 1):
			var cur := _cast(lerpf(t0, t1, float(k) / float(n)), rmax)
			_subdivide(prev, cur, 0, rmax)
			_emit(cur)
			prev = cur
	rays_cast = _rays
	_finish()


## One ray of the fan. Radius = distance from the eye to the first hit, or the range limit if nothing is hit.
func _cast(t: float, rmax: float) -> Sample:
	var s := Sample.new()
	s.t = t
	s.r = rmax
	var u := _dir.rotated(t)
	if rmax >= 0.5:  # a zero-length ray tells nothing
		_q.from = _eye
		_q.to = _eye + u * rmax
		_rays += 1
		var res := _space.intersect_ray(_q)
		if not res.is_empty():
			s.hit = true
			s.r = minf((res["position"] as Vector2).distance_to(_eye), rmax)
			s.cid = int(res["collider_id"])
			s.shape = int(res["shape"])
			s.normal = res["normal"]
	s.pos = origin + u * s.r
	return s


func _emit(s: Sample) -> void:
	_pts.append(s.pos)


## Adds the samples that are needed strictly between `a` and `b` (same radius limit), in angle order.
##  - both rays free: the boundary between them is the range arc, nothing to add;
##  - both hit the same flat face of the same shape: the chord IS the surface;
##  - otherwise cast the middle ray: a middle point within FLAT_TOL of the chord of two hits is flat enough; anything
##    else (a corner, a silhouette, a hit next to a free ray) is bisected further, down to MAX_DEPTH.
func _subdivide(a: Sample, b: Sample, depth: int, rmax: float) -> void:
	if depth >= MAX_DEPTH or b.t - a.t <= MIN_DT:
		return
	if _rays >= MAX_RAYS:
		capped = true
		return
	if not a.hit and not b.hit:
		return
	if a.hit and b.hit and a.cid == b.cid and a.shape == b.shape and a.normal.distance_to(b.normal) < 1.0e-3:
		return
	var m := _cast((a.t + b.t) * 0.5, rmax)
	if a.hit and b.hit and m.hit:
		if Geometry2D.get_closest_point_to_segment(m.pos, a.pos, b.pos).distance_to(m.pos) <= FLAT_TOL:
			return
	_subdivide(a, m, depth + 1, rmax)
	_emit(m)
	_subdivide(m, b, depth + 1, rmax)


## Merge near-duplicate neighbours (seams, hits at the same spot) and the closing duplicate of the full turn.
func _finish() -> void:
	var out := PackedVector2Array()
	for p in _pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= DUP_EPS:
			out.append(p)
	while out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < DUP_EPS:
		out.remove_at(out.size() - 1)
	points = out if out.size() >= 3 else PackedVector2Array()
	_pts = PackedVector2Array()
