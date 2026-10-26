class_name ProblemScan
extends RefCounted
## Builder lint: finds the mistakes that are easy to make by hand and hard to see.
##   "stacked"  two pieces of the same id on the same spot, or two floor tiles in one cell
##   "overlap"  two solid props whose footprints sit on top of each other
##   "shore"    a bank piece that does not match its neighbours (floating shore: no water or no land where it expects)
##   "bank"     water with land beside it but no bank piece, or water open to the white void
## Each problem is {kind, pos, msg}; `pos` is where the editor flags it and where NEXT PROBLEM flies to.

const SOLID_SKIP: Array[String] = ["grass", "ground", "pickup", "spawn", "fireflies", "water_fx", "blight_light", "wall"]


static func scan(placed: PlacedObjects) -> Array:
	var out: Array = []
	_stacked(placed, out)
	_overlaps(placed, out)
	_water(placed, out)
	return out


static func _stacked(placed: PlacedObjects, out: Array) -> void:
	var seen := {}
	var floor_cells := {}
	for o in placed.objects:
		var pos: Vector2 = o.pos
		if PlacedObjects.def_of(o.id).kind == "spawn":
			continue
		if PlacedObjects.is_floor_tile(o.id):
			var c := PlacedObjects.lattice_center(pos)
			if floor_cells.has(c):
				out.append({"kind": "stacked", "pos": c, "msg": "Two floor tiles share one cell"})
			floor_cells[c] = true
			continue
		var key := "%s@%d,%d" % [o.id, roundi(pos.x), roundi(pos.y)]
		if seen.has(key):
			out.append({"kind": "stacked", "pos": pos, "msg": "Two %s on the same spot" % PlacedObjects.def_of(o.id).get("label", o.id)})
		seen[key] = true


static func _overlaps(placed: PlacedObjects, out: Array) -> void:
	var items: Array = []
	for o in placed.objects:
		var kind: String = PlacedObjects.def_of(o.id).kind
		if kind in SOLID_SKIP:
			continue
		items.append([o, PlacedObjects.footprint_rect(o.id, o.pos).grow(-3.0)])
	var buckets := {}
	for i in items.size():
		var r: Rect2 = items[i][1]
		for bx in range(int(floor(r.position.x / 128.0)), int(floor(r.end.x / 128.0)) + 1):
			for by in range(int(floor(r.position.y / 128.0)), int(floor(r.end.y / 128.0)) + 1):
				var k := Vector2i(bx, by)
				if not buckets.has(k):
					buckets[k] = []
				buckets[k].append(i)
	var done := {}
	for k: Vector2i in buckets:
		var list: Array = buckets[k]
		for a in list.size():
			for b in range(a + 1, list.size()):
				var i: int = list[a]
				var j: int = list[b]
				var pair := Vector2i(mini(i, j), maxi(i, j))
				if done.has(pair):
					continue
				done[pair] = true
				var ra: Rect2 = items[i][1]
				var rb: Rect2 = items[j][1]
				var inter := ra.intersection(rb)
				if inter.size.x <= 0.0 or inter.size.y <= 0.0:
					continue
				var small := minf(ra.get_area(), rb.get_area())
				if small > 0.0 and inter.get_area() / small > 0.5:
					if items[i][0].pos.distance_to(items[j][0].pos) < 2.0 and items[i][0].id == items[j][0].id:
						continue  # already reported as stacked
					out.append({"kind": "overlap", "pos": (items[i][0].pos as Vector2).lerp(items[j][0].pos, 0.5), "msg": "%s overlaps %s" % [PlacedObjects.def_of(items[i][0].id).get("label", items[i][0].id), PlacedObjects.def_of(items[j][0].id).get("label", items[j][0].id)]})


static func _water(placed: PlacedObjects, out: Array) -> void:
	var tiler := AutoTile.new(placed)
	for o in placed.objects:
		var id: String = o.id
		var cell := PlacedObjects.lattice_center(o.pos as Vector2)
		if AutoTile.terrain_of(id) != "water":
			continue
		if AutoTile.is_shore(id):
			var mask := tiler.corner_mask(cell)
			if mask != AutoTile.shore_mask_of(id) and not (mask == 15 and AutoTile.shore_mask_of(id) == 14):
				out.append({"kind": "shore", "pos": cell, "msg": "Bank piece does not match its neighbours"})
		else:
			if tiler.corner_mask(cell) != 0:
				out.append({"kind": "bank", "pos": cell, "msg": "Water touches land but has no bank piece"})
			elif tiler.role_for(cell) != "center":
				out.append({"kind": "bank", "pos": cell, "msg": "Water is open to the void"})
