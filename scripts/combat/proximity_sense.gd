class_name ProximitySense
extends RefCounted
## Omnidirectional "power level" sense a sprinting ("naruto running") actor has for nearby threats --
## independent of any facing/vision cone and ignoring walls (a felt presence, not a sightline). Radius
## scales with the actor's `intelligence` stat: "the higher the stat the bigger the circle" (owner).
## Pure math + group queries only; never mutates a node. Shared by PlayerController and Bandit so the
## radius formula and the "who is nearest" scan live in exactly one place.
##
## PROVISIONAL PROTOTYPE values (WorldScale: a standing figure is 108 px tall). Not balance.

const BASE_RADIUS := 220.0      ## world px at intelligence 0
const RADIUS_PER_POINT := 16.0  ## additional world px per point of intelligence
const MIN_RADIUS := 120.0
const MAX_RADIUS := 900.0


## World-px radius of the sense circle for a given `intelligence` stat. Clamped to a sane range so a
## stat of 0 (or garbage/negative input) still gives a small, real circle instead of zero/negative.
static func radius_for(intelligence: int) -> float:
	var r := BASE_RADIUS + float(maxi(intelligence, 0)) * RADIUS_PER_POINT
	return clampf(r, MIN_RADIUS, MAX_RADIUS)


## Nearest living member of `group` within `radius` of `origin`, excluding `exclude` (normally the
## sensing actor itself). Returns null when nothing qualifies. Distance-only: no line-of-sight or
## facing check, because this is a felt presence/power-level sense, not sight -- it is not blocked by
## walls and does not care which way the sensing actor is facing. Only a body standing inside a smoke
## screen is masked.
static func nearest_in_radius(origin: Vector2, radius: float, group: String, tree: SceneTree, exclude: Node = null) -> Node2D:
	var nearest: Node2D = null
	var nearest_d := radius
	for node in tree.get_nodes_in_group(group):
		if node == exclude or not (node is Node2D):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if SmokeTagBomb.hides((node as Node2D).global_position):
			continue  # a body inside a smoke screen gives nothing away, not even to the sense
		var d: float = origin.distance_to((node as Node2D).global_position)
		if d <= nearest_d:
			nearest_d = d
			nearest = node
	return nearest