class_name ShrineElevation
extends RefCounted
## Simulated elevation for the Ancient Flame Shrine (DynamicShrine): a staircase that climbs to a round platform.
##
## The world is flat; an actor's `elevation` is a logical height, separate from its ground position. The ground
## position (collision, hit tests, y-sort key) never moves; only the figure is drawn higher:
##     visual_y = ground_y - elevation
## Elevation is a pure function of where the actor stands on the ground plane (`elevation_at`), so walking up the
## stairs raises it gradually, walking down lowers it, and nothing can teleport. The actor eases toward that
## target at a capped rate (RATE), which also smooths any teleport (a substitution) instead of snapping.
##
## All geometry is authored in art pixels of the 544x480 canvas (anchor FOOT) and converted to the shrine's local
## space, so it moves with the node. See docs/visuals/shrine-elevation/README.md for the overlay that was used to fit it.

const FOOT := Vector2(272, 448)
const HEIGHT := 72.0  ## platform height above the ground, px
const RATE := 480.0  ## max elevation change, px/s
const BOARD_AT := 0.5  ## fraction of HEIGHT at which an actor counts as being on the upper level
const RAMP_START := 0.12  ## stair parameter where the rise begins (the flat lip in front of the first step)
const EDGE_LAYER := 64  ## collision layer of the player-only walls (platform rim, stair sides); the player masks it
## Stair run in the ground plane: MOUTH is the centre of the entrance on the mound's front edge, TOP the centre of the
## top step; STAIR_HALF is the half-width vector (it follows the mound's front edge, so the mouth is flush with it).
const MOUTH := Vector2(178, 422)
const TOP := Vector2(266, 358)
const STAIR_HALF := Vector2(55, 28)
## Platform footprint on the ground plane (the visible platform ellipse shifted down by HEIGHT).
const PLATFORM_CENTER := Vector2(285, 310)
const PLATFORM_RADIUS := Vector2(108, 52)
## Mound footprint (the diamond the art stands on, inset a few px so feet meet the painted base).
const MOUND := [Vector2(272, 455), Vector2(44, 361), Vector2(272, 282), Vector2(494, 381)]
## The central monument's footprint on the platform (centre, radius), ground-plane coordinates. The arches stand on
## the platform rim, so the rim wall is their collision.
const MONUMENT := [Vector2(285, 312), Vector2(22, 6)]

## Every solid shrine in the tree (DynamicShrine registers itself).
static var zones: Array = []
## Other climbable terrain uses its own geometry, sharing the actor easing path.
static var terrain_zones: Array = []


static func _l(p: Vector2) -> Vector2:
	return p - FOOT


static func ellipse(center: Vector2, radius: Vector2, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(_l(center) + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


static func mound_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Vector2 in MOUND:
		pts.append(_l(p))
	return pts


static func platform_polygon(n: int = 32) -> PackedVector2Array:
	return ellipse(PLATFORM_CENTER, PLATFORM_RADIUS, n)


## The stair footprint (a parallelogram whose short sides run along the mound's front edge).
## `widen` > 1 widens it; `lead` extends the mouth outward (opposite to the climb) as a fraction of the run.
static func stair_polygon(widen: float = 1.0, lead: float = 0.0) -> PackedVector2Array:
	var run := TOP - MOUTH
	var c := STAIR_HALF * widen
	var m := MOUTH - run * lead
	return PackedVector2Array([_l(m - c), _l(m + c), _l(TOP + c), _l(TOP - c)])


## Position along the stairs, 0 at the mouth and 1 at the top step (unclamped), for a shrine-local point.
static func stair_t(local: Vector2) -> float:
	var run := TOP - MOUTH
	var q := local + FOOT - MOUTH
	var d := run.cross(STAIR_HALF)
	return q.cross(STAIR_HALF) / d


static func in_stairs(local: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(local, stair_polygon())


static func in_platform(local: Vector2) -> bool:
	var q := (local + FOOT - PLATFORM_CENTER) / PLATFORM_RADIUS
	return q.length_squared() <= 1.0


static func ramp(t: float) -> float:
	return HEIGHT * clampf((t - RAMP_START) / (1.0 - RAMP_START), 0.0, 1.0)


## Logical elevation of a shrine-local ground point.
static func elevation_at(local: Vector2) -> float:
	if in_platform(local):
		return HEIGHT
	if in_stairs(local):
		return ramp(stair_t(local))
	return 0.0


## Elevation an actor standing at world point `p` is heading to (max over all shrines).
static func target_at(p: Vector2) -> float:
	var best := 0.0
	for z in zones:
		if is_instance_valid(z) and z.is_inside_tree():
			best = maxf(best, elevation_at((z as Node2D).to_local(p)))
	for z in terrain_zones:
		if is_instance_valid(z) and z.is_inside_tree():
			best = maxf(best, z.elevation_at((z as Node2D).to_local(p)))
	return best


## Y of the mound's visible front edge at art x: the depth key a ground-level actor is compared against.
static func front_edge_y(art_x: float) -> float:
	var left: Vector2 = MOUND[1]
	var bottom: Vector2 = MOUND[0]
	var right: Vector2 = MOUND[3]
	if art_x <= bottom.x:
		return lerpf(left.y, bottom.y, clampf((art_x - left.x) / (bottom.x - left.x), 0.0, 1.0))
	return lerpf(bottom.y, right.y, clampf((art_x - bottom.x) / (right.x - bottom.x), 0.0, 1.0))


## Called every physics tick by an actor that has an `elevation` property: eases it toward the target for its current
## ground position and tells each shrine which level the actor is on (collision exceptions and draw order).
static func update_actor(actor: Node2D, delta: float) -> void:
	if zones.is_empty() and terrain_zones.is_empty() and actor.get("elevation") == 0.0:
		return
	var target := target_at(actor.global_position)
	var e: float = move_toward(float(actor.get("elevation")), target, RATE * delta)
	actor.set("elevation", e)
	var upper := e >= HEIGHT * BOARD_AT
	for z in zones:
		if is_instance_valid(z) and z.is_inside_tree():
			var lp := (z as Node2D).to_local(actor.global_position)
			var on_this := elevation_at(lp) > 0.0 or in_stairs(lp)
			z.set_actor_level(actor, upper and on_this, on_this and (e > 0.5 or in_stairs(lp)))

	for z in terrain_zones:
		if is_instance_valid(z) and z.is_inside_tree():
			var lp := (z as Node2D).to_local(actor.global_position)
			var local_height: float = z.elevation_at(lp)
			z.set_actor_level(actor, local_height > 0.0 and e >= z.height * BOARD_AT, local_height > 0.0)


## How far in front of a stair mouth (in stair runs) a walker lines up before climbing.
const CLIMB_LEAD := 1.0


## Stair geometry of any climbable zone, zone-local: mouth/top centres and the half-width across the tread.
static func _stairs_of(z: Node2D) -> Dictionary:
	if z in zones:
		return {"mouth": _l(MOUTH), "top": _l(TOP), "half": STAIR_HALF}
	return {"mouth": z.get("mouth"), "top": z.get("top"), "half": z.get("half_width")}


static func _zone_height(z: Node2D, local: Vector2) -> float:
	return elevation_at(local) if z in zones else float(z.elevation_at(local))


## Stair coordinates of a zone-local point: t runs 0 (mouth) .. 1 (top), s runs -1 .. 1 across the tread.
static func _stair_ts(g: Dictionary, local: Vector2) -> Vector2:
	var run: Vector2 = g.top - g.mouth
	var half: Vector2 = g.half
	var q: Vector2 = local - g.mouth
	return Vector2(q.cross(half) / run.cross(half), q.cross(run) / half.cross(run))


## Steering for a walker (any actor, not only the player) whose ground point is `from` and goal is `to`, when one of
## them is on a climbable surface. Empty when no zone is involved (ordinary nav applies). Otherwise {"target": world
## point, "direct": bool}: direct = steer straight at it (on or lined up with the stairs, where the grid nav has no
## say); not direct = path there with the nav (the line-up point in front of the mouth).
static func climb_step(from: Vector2, to: Vector2) -> Dictionary:
	for z in zones + terrain_zones:
		if not is_instance_valid(z) or not (z as Node2D).is_inside_tree():
			continue
		var node := z as Node2D
		var g := _stairs_of(node)
		var a := node.to_local(from)
		var b := node.to_local(to)
		var ta := _stair_ts(g, a)
		var tb := _stair_ts(g, b)
		var a_stairs := ta.x >= 0.0 and ta.x <= 1.0 and absf(ta.y) <= 1.0
		var b_stairs := tb.x >= 0.0 and tb.x <= 1.0 and absf(tb.y) <= 1.0
		var a_upper := not a_stairs and _zone_height(node, a) > 0.0
		var b_upper := not b_stairs and _zone_height(node, b) > 0.0
		if not (a_stairs or a_upper or b_stairs or b_upper):
			continue
		var run: Vector2 = g.top - g.mouth
		var top := node.to_global(g.top)
		var line_up := node.to_global(g.mouth - run * CLIMB_LEAD)
		if b_upper and not a_upper:
			if a_stairs or (ta.x > -CLIMB_LEAD - 0.25 and absf(ta.y) <= 1.0):
				return {"target": top if ta.x < 0.95 else to, "direct": true}
			return {"target": line_up, "direct": false}
		if b_stairs and not (a_stairs or a_upper):
			if ta.x > -CLIMB_LEAD - 0.25 and absf(ta.y) <= 1.0:
				return {"target": to, "direct": true}
			return {"target": line_up, "direct": false}
		if a_upper and not b_upper:
			if a.distance_to(g.top) > 12.0 and not b_stairs:
				return {"target": top, "direct": true}
			return {"target": to if b_stairs else line_up, "direct": true}
		if a_stairs and not (b_stairs or b_upper):
			return {"target": line_up, "direct": true}
		return {"target": to, "direct": true}
	return {}
