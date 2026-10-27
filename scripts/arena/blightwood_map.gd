class_name BlightwoodMap
extends RefCounted
## The STARTING MAP, recreated from the owner's low-poly terrain map and the Blightwood Forest reference shot:
## a dirt courtyard with the Ancient Shrine at its back, three lit braziers, rocks, fences, stone terrace at the top,
## cliffs round the edges, lakes, a waterfall pool and a wooden bridge at the lower right.
## Terrain comes from BlightwoodMapData (sampled from the low-poly map onto the 72 x 36 floor lattice); props are
## placed from reference-image pixel positions. Built only from existing PlacedObjects catalog art.
## A transient authored layer (commit=false) that runs once per layout, like AncientShrineSection.

## Reference pixel -> world: the low-poly picture is 1672 x 941, the courtyard centre (800, 440) is the world origin.
const SCALE := 1.6
const REF_CENTER := Vector2(800, 440)
const CLIFF_TILE := "shore_rock_15"  ## rocky-bank "land fill": the cliff / rock-wall ground art
const TERRAIN_ID := {"g": "grass", "d": "ground", "s": "temple", "w": "water"}

## Master switch: the test suite turns it off so the default-arena object counts its tests assume stay put.
static var enabled := true


static func pw(px: float, py: float) -> Vector2:
	return (Vector2(px, py) - REF_CENTER) * SCALE


## Where the player starts: the middle of the dirt courtyard.
static func spawn_point() -> Vector2:
	return PlacedObjects.lattice_center(pw(800, 500))


## Terrain cells by char ("g" "d" "s" "c" "w") -> Array of lattice centres.
static func terrain_cells() -> Dictionary:
	var out := {"g": [], "d": [], "s": [], "c": [], "w": []}
	var rows := BlightwoodMapData.ROWS
	for r in rows.size():
		var line: String = rows[r]
		for i in line.length():
			var ch := line[i]
			if out.has(ch):
				out[ch].append(Vector2(36.0 * (BlightwoodMapData.K_MIN + i), 18.0 * (BlightwoodMapData.M_MIN + r)))
	return out


## Map stair: mouth on a floor-diamond vertex so its two-edge tread lines up with the tiles.
static func stair_point() -> Vector2:
	return PlacedObjects.iso_vertex(pw(385, 705))


## Dirt cells behind the stair head, under the catalog landing (two edges wide, three deep).
static func stair_landing() -> Array[Vector2]:
	var def := PlacedObjects.def_of("earth_stairs_se")
	var top: Vector2 = stair_point() + (def.ramp_top as Vector2)
	var half: Vector2 = def.ramp_half
	var back := Vector2(36, -18) * 3.0
	var area := PackedVector2Array([top - half, top + half, top + half + back, top - half + back])
	var landing: Array[Vector2] = []
	for i in 4:
		for j in 6:
			var c := PlacedObjects.lattice_center(top - half + Vector2(36, 18) * (i + 0.5) * 0.5 + Vector2(36, -18) * (j + 0.5) * 0.5)
			if Geometry2D.is_point_in_polygon(c, area) and not landing.has(c):
				landing.append(c)
	return landing


## Props: [id, world position]. Positions are reference-image pixels run through pw().
static func props() -> Array:
	var p: Array = []
	p.append(["ancient_shrine", pw(640, 388)])
	for b in [Vector2(765, 392), Vector2(1110, 424), Vector2(713, 582)]:
		p.append(["blight_stone_brazier", pw(b.x, b.y)])
	var rocks := [Vector2(545, 425), Vector2(875, 410), Vector2(800, 472), Vector2(972, 486), Vector2(835, 548), Vector2(650, 588)]
	for i in rocks.size():
		p.append(["blight_rock_0%d" % (i % 3 + 1), pw(rocks[i].x, rocks[i].y)])
	p.append(["blight_stone_pagoda", pw(1000, 333)])
	p.append(["blight_wooden_post", pw(520, 470)])
	p.append(["blight_fireflies", pw(800, 470)])
	for t in [["tree_3", 90, 300], ["tree_4", 210, 380], ["tree_1", 150, 190], ["tree_2", 330, 300], ["tree_5", 60, 120], ["tree_4", 440, 215],
			["tree_5", 1400, 145], ["tree_4", 540, 640], ["tree_3", 260, 590], ["tree_1", 1040, 235]]:
		p.append([t[0], pw(t[1], t[2])])
	for g in [Vector2(580, 450), Vector2(480, 520), Vector2(1120, 470), Vector2(940, 600), Vector2(1030, 640), Vector2(290, 480)]:
		p.append(["grass_tall_0%d" % (int(g.x + g.y) % 4), pw(g.x, g.y)])
	p.append(["waterfall_small", pw(800, 725)])
	var stair := stair_point()
	p.append(["earth_stairs_se", stair])
	# Cliff faces continue the stair-head line on both sides: the left ledge ends at the top's
	# back corner, the right one starts at its front corner (ledge front run = (200, 100)).
	for ledge in stair_ledges():
		p.append(["cliff_ledge_se", ledge])
	p.append(["bridge_medium_wood_u", pw(1370, 735)])
	return p


## Ground points of the two cliff ledges flanking the stair head.
static func stair_ledges() -> Array[Vector2]:
	var def := PlacedObjects.def_of("earth_stairs_se")
	var top: Vector2 = stair_point() + (def.ramp_top as Vector2)
	var half: Vector2 = def.ramp_half
	var run: Vector2 = PlacedObjects.def_of("cliff_ledge_se").col
	return [top - half - run, top + half]


## Fences: [id, upper end]. "se" pieces run down-right from the point, "sw" pieces down-left.
static func fences() -> Array:
	return [
		["fence_sw_3", pw(670.75, 221.25)],   # behind the shrine (nudged off the cliff rock)
		["fence_sw_3", pw(570, 300)],   # left of the shrine
		["fence_se_4", pw(742, 208)],   # back right, down to the right brazier
		["fence_se_3", pw(920, 300)],
		["fence_sw_4", pw(432, 450)],   # far-left run to the stairs rock (mirrored: falls toward the cliff)
		["fence_se_3", pw(265, 440)],  # nudged right off the cliff rock
		["fence_se_4", pw(935, 540)],   # front right, toward the bridge
		["fence_se_2", pw(1160, 500)],
		["fence_se_4", pw(1192.5, 620)],  # nudged down off the cliff rock
		["fence_se_3", pw(1050, 60)],   # top right, beside the stream (nudged up off the cliff rock so it stays walkable)
		["fence_sw_1", pw(800, 880)],
		["fence_sw_1", pw(1160, 880)],
	]


static func populate(arena: TrainingArena) -> int:
	if not enabled or arena == null or arena.placed == null:
		return 0
	var placed := arena.placed
	if placed.blightwood_map_applied:
		return 0
	var had_content := placed.objects.size() > 0
	if had_content:
		_backup_previous(placed)
	# Start clean: the map is a whole starting layout. Only the player spawn survives (re-seated below).
	for o: Dictionary in placed.objects.duplicate():
		placed.remove(o, false)
	var cells := terrain_cells()
	for c: Vector2 in cells.c:
		placed.paint_cell(CLIFF_TILE, c)
	var tiler := AutoTile.new(placed)
	for ch in ["g", "d", "s"]:
		tiler.apply(cells[ch], TERRAIN_ID[ch])
	tiler.apply(cells.w, "water")
	# Dirt landing joins the stair head to the terrace, rather than ending in rock fill.
	tiler.apply(stair_landing(), "ground")
	var count := 0
	var spawn := spawn_point()
	if placed.can_place("player_spawn", spawn):
		placed.add("player_spawn", spawn, false)
	for item: Array in props():
		var id: String = item[0]
		var pos: Vector2 = item[1]
		if not arena.bounds.has_point(pos):
			continue
		if placed.can_place(id, pos) and not placed.add(id, pos, false).is_empty():
			count += 1
	for item: Array in fences():
		if placed.can_place(item[0], item[1]) and not placed.add(item[0], item[1], false).is_empty():
			count += 1
	placed.link_stair_zones()
	placed.blightwood_map_applied = true
	placed.shrine_section_applied = true  # the old courtyard section must not be laid over the map
	arena.rebuild_nav()
	return count


static func _backup_previous(placed: PlacedObjects) -> void:
	if placed.save_path != PlacedObjects.SAVE_PATH:
		return
	var f := FileAccess.open("user://world_layout.before_blightwood.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(placed.to_dict()))
