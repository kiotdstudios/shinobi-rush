class_name AncientShrineSection
extends RefCounted
## The STARTING AREA: a fenced stone courtyard around the player spawn, with the Ancient Shrine at its back,
## braziers in the corners, lanterns flanking two exits, trees and tall grass outside.
## Layout follows the owner's close-combat mockup (a raised stone terrace with balustrades and lit braziers),
## built only from existing PlacedObjects catalog art; the mockup itself is never rasterised.
## This is a transient authored layer (add/remove with commit=false) so local World Builder saves are not overwritten.

## Courtyard size in floor tiles per side. Tile step along SE is (72, 36), along SW is (-72, 36).
const N := 8
## Top tile centre. The spawn (0, 135) lands at the courtyard centre; the two fire pillars at (+-230, 260) stand just inside the front fences.
const ORIGIN := Vector2(0, -125)
const STEP_SE := Vector2(72, 36)
const STEP_SW := Vector2(-72, 36)
## Fence pieces of 2 tile-units each; the listed piece index (0-based) is left out as an exit.
const EXIT_FRONT_LEFT := 1
const EXIT_FRONT_RIGHT := 1
const FLOOR_VARIANTS: Array = ["temple_floor_center", "temple_floor_center", "temple_floor_center_b", "temple_floor_center", "temple_floor_cracked_a", "temple_floor_center", "temple_floor_moss_a", "temple_floor_cracked_b"]

## Master switch: the test suite turns it off so the default-arena object counts its tests assume stay put.
static var enabled := true


## Centre of the floor tile at grid (i along SE, j along SW); fractions are fine.
static func tp(i: float, j: float) -> Vector2:
	return ORIGIN + STEP_SE * i + STEP_SW * j


static func _floor_id(i: int, j: int) -> String:
	var last := N - 1
	if i == 0 and j == 0:
		return "temple_floor_corner_top"
	if i == last and j == 0:
		return "temple_floor_corner_right"
	if i == 0 and j == last:
		return "temple_floor_corner_left"
	if i == last and j == last:
		return "temple_floor_corner_bottom"
	if j == 0:
		return "temple_floor_edge_ne"
	if i == 0:
		return "temple_floor_edge_nw"
	if i == last:
		return "temple_floor_edge_se"
	if j == last:
		return "temple_floor_edge_sw"
	return FLOOR_VARIANTS[(i * 5 + j * 3) % FLOOR_VARIANTS.size()]


## Everything the section places: [id, position].
static func layout() -> Dictionary:
	var floor_tiles: Array = []
	for i in N:
		for j in N:
			floor_tiles.append([_floor_id(i, j), tp(i, j)])
	var top := ORIGIN + Vector2(0, -36)
	var right := top + STEP_SE * N
	var left := top + STEP_SW * N
	var fences: Array = []
	var pieces := N / 2
	for k in pieces:
		fences.append(["fence_se_2", top + STEP_SE * 2.0 * k])  # back-right edge
		fences.append(["fence_sw_2", top + STEP_SW * 2.0 * k])  # back-left edge
		if k != EXIT_FRONT_LEFT:
			fences.append(["fence_se_2", left + STEP_SE * 2.0 * k])  # front-left edge
		if k != EXIT_FRONT_RIGHT:
			fences.append(["fence_sw_2", right + STEP_SW * 2.0 * k])  # front-right edge
	var props: Array = [
		# Corner braziers (back and both sides; the front stays open so the camera sees the way out).
		["blight_stone_brazier", tp(3.4, 1.2)], ["blight_stone_brazier", tp(N - 2, 1)],
		["blight_stone_brazier", tp(1, N - 2)],
		# Lanterns flanking the two exits.
		["blight_stone_pagoda", tp(0.8, N - 1)], ["blight_stone_pagoda", tp(3.2, N - 1)],
		["blight_stone_pagoda", tp(N - 1, 0.8)], ["blight_stone_pagoda", tp(N - 1, 3.2)],
		# Trees outside the fence, never in front of the exits.
		["tree_3", ORIGIN + Vector2(-330, 40)], ["tree_4", ORIGIN + Vector2(330, 40)],
		["tree_2", ORIGIN + Vector2(-690, 250)], ["tree_5", ORIGIN + Vector2(690, 250)],
		["tree_1", ORIGIN + Vector2(0, -90)],
		# Tall grass outside the exits.
		["grass_tall_00", tp(2.5, N + 1.2)], ["grass_tall_01", tp(3.6, N + 1.6)],
		["grass_tall_02", tp(N + 1.2, 2.5)], ["grass_tall_03", tp(N + 1.6, 3.6)],
		["blight_fireflies", tp(N * 0.5, N * 0.5)]
	]
	return {"floor": floor_tiles, "fences": fences, "props": props, "shrine": tp(1.6, 3.6)}


## True when a world point lies inside the courtyard diamond grown by `margin` pixels.
static func covers(p: Vector2, margin: float) -> bool:
	var c := tp((N - 1) * 0.5, (N - 1) * 0.5)
	var half := Vector2(N * 72.0 + margin * 2.0, N * 36.0 + margin)
	var d := p - c
	return absf(d.x) / half.x + absf(d.y) / half.y <= 1.0


static func populate(arena: TrainingArena) -> int:
	if not enabled:
		return 0
	if arena == null or arena.placed == null:
		return 0
	var placed := arena.placed
	var lay := layout()
	# Clear loose scenery (trees, rocks, old section props) from the courtyard footprint; the shrine is re-seated below.
	for o: Dictionary in placed.objects.duplicate():
		var kind: String = PlacedObjects.def_of(o.id).get("kind", "")
		if kind in ["ground", "grass", "pickup"]:
			continue
		if covers(o.pos, 60.0):
			placed.remove(o, false)
	var count := 0
	var shrine_pos: Vector2 = lay.shrine
	for o: Dictionary in placed.objects.duplicate():
		if o.id == "ancient_shrine":
			placed.remove(o, false)
	if placed.can_place("ancient_shrine", shrine_pos) and not placed.add("ancient_shrine", shrine_pos, false).is_empty():
		count += 1
	for item: Array in lay.props:
		var id: String = item[0]
		var pos: Vector2 = item[1]
		if not placed.can_place(id, pos):
			continue
		var def := PlacedObjects.def_of(id)
		var solid: bool = def.kind not in ["ground", "grass", "fireflies", "water_fx"] and not def.has("water_role")
		if solid and placed._overlaps_solid(PlacedObjects.footprint_rect(id, pos).grow(12.0)):
			continue
		if not placed.add(id, pos, false).is_empty():
			count += 1
	# Fences and floor go last: the floor tiles would otherwise read as solids and block the props above.
	for item: Array in lay.fences:
		if placed.can_place(item[0], item[1]) and not placed.add(item[0], item[1], false).is_empty():
			count += 1
	for item: Array in lay.floor:
		if placed.can_place(item[0], item[1]) and not placed.add(item[0], item[1], false).is_empty():
			count += 1
	arena.rebuild_nav()
	return count
