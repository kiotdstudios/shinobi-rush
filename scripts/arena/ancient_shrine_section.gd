class_name AncientShrineSection
extends RefCounted
## Reference-inspired shrine courtyard arrangement. All objects use existing PlacedObjects
## catalog art and placement logic; never rasterize the reference screenshot.
## This is a transient authored layer so local World Builder saves are not overwritten.

const GROUND: Array = [
	["ground9_center", Vector2(-216, 38)], ["ground9_center", Vector2(-144, 74)],
	["ground9_center", Vector2(-72, 110)], ["ground9_center", Vector2(0, 146)],
	["ground9_center", Vector2(72, 182)], ["ground9_center", Vector2(144, 218)],
	["ground9_center", Vector2(216, 254)], ["ground9_center", Vector2(288, 290)],
	["ground9_center", Vector2(-288, 218)], ["ground9_center", Vector2(-216, 254)],
	["ground9_center", Vector2(-144, 290)]
]
const WATER: Array = [
	["water9_corner_top", Vector2(-72, 380)],
	["water9_edge_ne", Vector2(0, 416)],
	["water9_center", Vector2(72, 452)],
	["water9_center", Vector2(144, 488)],
	["water9_edge_se", Vector2(216, 524)],
	["water9_center", Vector2(288, 560)],
	["water9_corner_bottom", Vector2(360, 596)]
]
const PROPS: Array = [
	# Back perimeter, terrace and corner trees.
	["tree_3", Vector2(-320, -155)], ["tree_2", Vector2(-450, -20)],
	["tree_4", Vector2(310, -160)], ["tree_5", Vector2(460, 55)],
	# Fences: diagonal isometric runs enclosing the courtyard.
	["fence_se_2", Vector2(-380, -80)], ["fence_se_2", Vector2(90, -205)],
	["fence_sw_2", Vector2(370, -100)], ["fence_sw_2", Vector2(-390, 180)],
	["fence_se_2", Vector2(170, 290)],
	# Four different illuminated fixtures, balanced across terrace.
	["blight_stone_brazier", Vector2(-240, -100)],
	["blight_stone_pagoda", Vector2(240, -105)],
	["blight_wooden_post", Vector2(-280, 210)],
	["blight_stone_brazier", Vector2(300, 215)],
	# Waterfall dropping from the front edge of the raised courtyard.
	["waterfall_small", Vector2(10, 360)],
	# Lower trail vegetation; replaces stairs with tall grass and trees.
	["grass_tall_00", Vector2(-430, 315)], ["grass_tall_01", Vector2(-385, 355)],
	["grass_tall_02", Vector2(-340, 395)], ["grass_tall_03", Vector2(-290, 435)],
	["tree_1", Vector2(-470, 455)], ["tree_5", Vector2(-340, 565)],
	["grass_tall_01", Vector2(265, 625)], ["grass_tall_02", Vector2(325, 660)],
	["blight_stone_pagoda", Vector2(-210, 555)],
	["blight_fireflies", Vector2(110, 545)]
]

static func populate(arena: TrainingArena) -> int:
	if arena == null or arena.placed == null:
		return 0
	var anchor := Vector2(330, -330)
	for item in arena.placed.objects:
		if item.id == "ancient_shrine":
			anchor = item.pos
			break
	var count := 0
	# Ground and water have no navigation collision.
	for item in GROUND + WATER + PROPS:
		var id: String = item[0]
		var pos: Vector2 = anchor + item[1]
		if not arena.placed.can_place(id, pos):
			continue
		# Avoid stacking new solid props on the existing shrine or other placed solids.
		var def := PlacedObjects.def_of(id)
		var solid := def.kind not in ["ground", "grass", "fireflies", "water_fx"] and not def.has("water_role")
		if solid and arena.placed._overlaps_solid(PlacedObjects.footprint_rect(id, pos).grow(12.0)):
			continue
		if not arena.placed.add(id, pos, false).is_empty():
			count += 1
	arena.rebuild_nav()
	return count
