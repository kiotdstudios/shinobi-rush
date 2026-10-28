extends RefCounted
## Automatic multi-material terrain blending (grass / ground / dirt / temple / rock): material identity, corner-mask
## selection for all 8 pairs x 16 masks x both polarities, paint / erase / undo / redo / save / reload, locks, junctions.

var ck: Callable
const SE := Vector2(36, 18)
const NE := Vector2(36, -18)


func _block(a: Vector2, ni: int, nj: int) -> Array:
	var out: Array = []
	for i in ni:
		for j in nj:
			out.append(a + SE * float(i) + NE * float(j))
	return out


func _id(placed: PlacedObjects, cell: Vector2) -> String:
	var t := placed.floor_tiles_in_cell(cell)
	return String(t[0].id) if t.size() == 1 else ""


func _fresh(placed: PlacedObjects) -> void:
	placed.load_dict({"version": 7, "items": []})
	placed.clear_history()


## Count disagreeing shared corners between neighbouring blended tiles (0 = every seam is continuous).
func _seam_errors(placed: PlacedObjects, cells: Array) -> int:
	var votes := {}
	for c: Vector2 in cells:
		var sig := TerrainBlend.signature_of(_id(placed, c))
		if sig.size() != 4:
			continue
		var vs := [c + Vector2(0, -18), c + Vector2(36, 0), c + Vector2(-36, 0), c + Vector2(0, 18)]
		for i in 4:
			if not votes.has(vs[i]):
				votes[vs[i]] = {}
			votes[vs[i]][sig[i]] = true
	var bad := 0
	for v in votes:
		if votes[v].size() > 1:
			bad += 1
	return bad


func _seam_vertices(placed: PlacedObjects, cells: Array) -> Array:
	var votes := {}
	for c: Vector2 in cells:
		var sig := TerrainBlend.signature_of(_id(placed, c))
		if sig.size() != 4:
			continue
		var vs := [c + Vector2(0, -18), c + Vector2(36, 0), c + Vector2(-36, 0), c + Vector2(0, 18)]
		for i in 4:
			if not votes.has(vs[i]):
				votes[vs[i]] = {}
			votes[vs[i]][sig[i]] = true
	var out: Array = []
	for v in votes:
		if votes[v].size() > 1:
			out.append(v)
	return out


func _missing(placed: PlacedObjects, cells: Array) -> int:
	var n := 0
	for c: Vector2 in cells:
		if _id(placed, c) == "" or PlacedObjects.def_of(_id(placed, c)).is_empty():
			n += 1
	return n


func _tiler(placed: PlacedObjects) -> AutoTile:
	var t := AutoTile.new(placed)
	t.blend = true
	return t


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	# ---- pure logic: every family, all 16 masks, both polarities
	var all_ok := true
	var reg_ok := true
	for fid: String in TerrainBlend.FAMILIES:
		var f: Array = TerrainBlend.FAMILIES[fid]
		for mask in 16:
			for v in ["a", "b", "c"]:
				var id := "%s_%02d_%s" % [fid, mask, v]
				if v != "a" and (mask == 0 or mask == 15) and fid != "path_dirt":
					continue
				if PlacedObjects.def_of(id).is_empty():
					reg_ok = false
			var corners: Array = []
			for bit in TerrainBlend.BITS:
				corners.append(f[1] if (mask & bit) != 0 else f[0])
			for own in [f[0], f[1]]:  # polarity: the cell's own material may be either side of the pair
				var res := TerrainBlend.resolve(own, corners)
				if mask == 0 or mask == 15:
					all_ok = all_ok and res.has("pure") and res.pure == (f[1] if mask == 15 else f[0])
				else:
					all_ok = all_ok and res.get("family", "") == fid and int(res.get("mask", -1)) == mask
				var id2 := TerrainBlend.tile_id(res, Vector2(72, 36))
				all_ok = all_ok and not PlacedObjects.def_of(id2).is_empty()
				var sig := TerrainBlend.signature_of(id2)
				all_ok = all_ok and sig == corners
	ck.call("blend: 10 families x 16 masks are all registered", reg_ok)
	ck.call("blend: resolve() round-trips every family/mask for both polarities", all_ok)
	ck.call("blend: all 10 material pairs have art", TerrainBlend.pair_family("grass", "dirt") != "" and TerrainBlend.pair_family("dirt", "grass") != "" and TerrainBlend.pair_family("ground", "temple") == "path_temple" and TerrainBlend.pair_family("ground", "rock") == "path_rock")
	ck.call("blend: bit convention bottom=1 left=2 right=4 top=8 (set corner = family 'one')", TerrainBlend.signature_of("grass_dirt_08_a") == ["grass", "dirt", "dirt", "dirt"] and TerrainBlend.signature_of("path_dirt_01_b") == ["ground", "ground", "ground", "dirt"] and TerrainBlend.signature_of("temple_rock_04_c") == ["rock", "temple", "rock", "rock"])
	ck.call("blend: variants are deterministic", TerrainBlend.variant_for(Vector2(144, 72)) == TerrainBlend.variant_for(Vector2(144, 72)))
	ck.call("blend: three materials never pick a missing tile", TerrainBlend.resolve("grass", ["grass", "dirt", "rock", "grass"]).has("junction") and not PlacedObjects.def_of(TerrainBlend.tile_id(TerrainBlend.resolve("grass", ["grass", "dirt", "rock", "grass"]), Vector2.ZERO)).is_empty())
	ck.call("blend: ground next to temple uses path_temple", TerrainBlend.resolve("ground", ["ground", "temple", "temple", "ground"]).get("family", "") == "path_temple")

	# Exact three-material junctions: all ten triples, each generated orientation.
	var triples_ok := true
	var triple_count := 0
	for a in range(5):
		for b in range(a + 1, 5):
			for c in range(b + 1, 5):
				var mats := [TerrainBlend.MATERIALS[a], TerrainBlend.MATERIALS[b], TerrainBlend.MATERIALS[c]]
				for sig in [[mats[0], mats[0], mats[1], mats[2]], [mats[0], mats[1], mats[0], mats[2]], [mats[0], mats[1], mats[2], mats[0]]]:
					var result := TerrainBlend.resolve(mats[0], sig)
					var id: String = TerrainBlend.tile_id(result, Vector2.ZERO)
					triples_ok = triples_ok and id.begins_with("junction_") and not PlacedObjects.def_of(id).is_empty() and TerrainBlend.signature_of(id) == sig
					triple_count += 1
	ck.call("blend: all ten triples resolve to exact registered junctions", triples_ok, "signatures=%d" % triple_count)
	var exact_count := 0
	var all_exact := true
	for family: Dictionary in TerrainJunctionArt.data().junctions:
		for tile: Dictionary in family.tiles:
			var resolved := TerrainBlend.tile_id(TerrainBlend.resolve(tile.corners[0],tile.corners),Vector2.ZERO)
			all_exact = all_exact and resolved==tile.id and TerrainBlend.signature_of(resolved)==tile.corners
			exact_count+=1
	ck.call("blend: all 360 authored junction signatures round trip",all_exact and exact_count==360)

	# ---- in the real builder
	AncientShrineSection.enabled = false
	var previous_map_mode := MapEditorMode.forced
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_terrain_blend_layout.json"
	placed.autosave = false
	arena.editor.void_check = false
	var origin := PlacedObjects.lattice_center(arena.bounds.get_center())

	# every pair: a stripe of B through a field of A is seam-free and fully tiled
	var pairs := [["grass", "dirt"], ["grass", "ground"], ["ground", "dirt"], ["grass", "temple"], ["dirt", "temple"], ["grass", "rock"], ["dirt", "rock"], ["temple", "rock"], ["ground", "temple"], ["ground", "rock"]]
	for pr in pairs:
		_fresh(placed)
		var field := _block(origin, 7, 7)
		var t := _tiler(placed)
		t.apply(field, pr[0])
		t.apply(_block(origin + SE * 3.0, 1, 7), pr[1])
		placed._changed(false)
		ck.call("blend: %s stripe through %s: nothing missing" % [pr[1], pr[0]], _missing(placed, field) == 0)
		ck.call("blend: %s stripe through %s: every seam continuous" % [pr[1], pr[0]], _seam_errors(placed, field) == 0, "bad=%d" % _seam_errors(placed, field))
		ck.call("blend: %s stripe uses a transition tile" % pr[1], TerrainBlend.parse_transition(_id(placed, origin + SE * 2.0 + NE * 3.0)).get("family", "") == TerrainBlend.pair_family(pr[0], pr[1]))
		ck.call("blend: %s stripe interior is the pure %s tile" % [pr[1], pr[1]], TerrainBlend.pure_material(_id(placed, origin + SE * 3.0 + NE * 3.0)) == pr[1], _id(placed, origin + SE * 3.0 + NE * 3.0) + " mat=" + str(placed.cell_mat.get(origin + SE * 3.0 + NE * 3.0)))

	# dirt trail with bends / T / four-way / island / diagonal through grass
	_fresh(placed)
	var area := _block(origin, 9, 9)
	var t1 := _tiler(placed)
	t1.apply(area, "grass")
	var trail: Array = []
	for k in 6:
		trail.append(origin + SE * float(k) + NE * 4.0)  # straight run
	for k in 4:
		trail.append(origin + SE * 5.0 + NE * (4.0 + float(k)))  # bend
	for k in 4:
		trail.append(origin + SE * 2.0 + NE * float(k))  # branch -> T
	trail.append(origin + SE * 7.0 + NE * 1.0)  # island
	trail.append(origin + SE * 7.0 + NE * 7.0 + NE)  # diagonal pair part 1
	trail.append(origin + SE * 8.0 + NE * 7.0 + SE * 0.0)
	t1.apply(trail, "dirt")
	placed._changed(false)
	ck.call("blend: dirt trail with bend, T, island and diagonal: nothing missing", _missing(placed, area) == 0)
	ck.call("blend: dirt trail: every seam continuous", _seam_errors(placed, area) == 0, "bad=%d" % _seam_errors(placed, area))
	ck.call("blend: painted dirt cells never lose their owner (cell_mat is dirt)", placed.cell_mat.get(trail[0], "") == "dirt" and placed.cell_mat.get(trail[7], "") == "dirt")
	var snapshot := {}
	for c: Vector2 in area:
		snapshot[c] = _id(placed, c)
	# deterministic: repainting the same cells keeps every tile
	t1.apply(trail, "dirt")
	var same := true
	for c: Vector2 in area:
		same = same and snapshot[c] == _id(placed, c)
	ck.call("blend: repaint is stable (A/B/C variants do not reshuffle)", same)

	# save / reload keeps tiles + ownership
	var dumped := placed.to_dict()
	placed.load_dict(dumped)
	var reloaded := true
	for c: Vector2 in area:
		reloaded = reloaded and snapshot[c] == _id(placed, c)
	ck.call("blend: save/reload restores every tile", reloaded)
	ck.call("blend: save/reload restores cell ownership", placed.cell_mat.get(trail[0], "") == "dirt" and placed.cell_mat.get(origin, "") == "grass")
	var t2 := _tiler(placed)
	t2.apply([origin + SE * 2.0 + NE * 8.0], "dirt")  # re-edit after reload
	ck.call("blend: re-edit after reload still blends", _missing(placed, area) == 0 and _seam_errors(placed, area) == 0)

	# undo / redo is one step per gesture and restores ownership
	_fresh(placed)
	var t3 := _tiler(placed)
	t3.apply(_block(origin, 5, 5), "grass")
	placed._changed(false)
	var before := {}
	for c: Vector2 in _block(origin, 5, 5):
		before[c] = _id(placed, c)
	var stripe := _block(origin + SE * 2.0, 1, 5)
	t3.apply(stripe, "dirt")
	placed._changed(false)
	var after := {}
	for c: Vector2 in _block(origin, 5, 5):
		after[c] = _id(placed, c)
	placed.undo()
	var undone := true
	for c: Vector2 in before:
		undone = undone and before[c] == _id(placed, c)
	ck.call("blend: undo reverts the whole drag in one step", undone)
	ck.call("blend: undo reverts ownership", placed.cell_mat.get(stripe[0], "") == "grass")
	placed.redo()
	var redone := true
	for c: Vector2 in after:
		redone = redone and after[c] == _id(placed, c)
	ck.call("blend: redo reapplies the drag", redone and placed.cell_mat.get(stripe[0], "") == "dirt")

	# erase re-tiles the neighbours
	var t4 := _tiler(placed)
	var mid: Vector2 = origin + SE * 2.0 + NE * 2.0
	t4.erase(placed.floor_tiles_in_cell(mid)[0])
	placed._changed(false)
	ck.call("blend: erase removes the tile and clears ownership", _id(placed, mid) == "" and not placed.cell_mat.has(mid))

	# manual lock survives neighbours
	_fresh(placed)
	var t5 := _tiler(placed)
	t5.apply(_block(origin, 5, 5), "grass")
	var locked: Vector2 = origin + SE * 2.0 + NE * 2.0
	t5.lock(locked)
	var locked_id := _id(placed, locked)
	t5.apply(_block(origin + SE * 3.0, 2, 5), "dirt")
	ck.call("blend: a locked tile is never retiled", _id(placed, locked) == locked_id and t5.is_locked(locked))
	var reload_lock := placed.to_dict()
	placed.load_dict(reload_lock)
	ck.call("blend: lock persists through save/reload", _tiler(placed).is_locked(locked))
	t5.unlock(locked)
	ck.call("blend: unlock hands the tile back to auto-blend", not _tiler(placed).is_locked(locked))

	# Moving a managed floor tile carries its owner and participates in undo/redo.
	_fresh(placed)
	var move_tiler := _tiler(placed)
	var move_from: Vector2 = origin
	var move_to: Vector2 = origin + SE * 3.0
	move_tiler.apply([move_from], "dirt")
	placed._changed(false)
	var moving: Dictionary = placed.floor_tiles_in_cell(move_from)[0]
	placed.move(moving, move_to)
	ck.call("blend: move transfers terrain owner", not placed.cell_mat.has(move_from) and String(placed.cell_mat.get(move_to, "")) == "dirt")
	placed.undo()
	ck.call("blend: undo move restores terrain owner", String(placed.cell_mat.get(move_from, "")) == "dirt" and not placed.cell_mat.has(move_to))
	placed.redo()
	ck.call("blend: redo move transfers terrain owner again", not placed.cell_mat.has(move_from) and String(placed.cell_mat.get(move_to, "")) == "dirt")

	# a hand-placed transition tile on a managed cell becomes a manual override
	_fresh(placed)
	var t6 := _tiler(placed)
	t6.apply(_block(origin, 3, 3), "grass")
	var hand: Vector2 = origin + SE + NE
	var hand_id := "grass_dirt_06_b"
	placed.paint_cell(hand_id, hand)
	ck.call("blend: manual placement locks the cell", String(placed.cell_mat.get(hand, "")) == "lock")
	_tiler(placed).apply([origin], "dirt")
	ck.call("blend: manual transition persists while neighbours change", _id(placed, hand) == hand_id)

	# legacy maps are not touched by merely opening them
	placed.load_dict({"version": 7, "items": [{"id": "grass9_center", "x": origin.x, "y": origin.y}, {"id": "ground9_center", "x": origin.x + 36, "y": origin.y + 18}, {"id": "grass_dirt_03_a", "x": origin.x + 72, "y": origin.y}]})
	ck.call("blend: loading a legacy map keeps tiles and adds no ownership", _id(placed, origin) == "grass9_center" and _id(placed, origin + SE) == "ground9_center" and _id(placed, origin + Vector2(72, 0)) == "grass_dirt_03_a" and placed.cell_mat.is_empty())
	ck.call("blend: legacy save output has no mat keys", not placed.to_json_string().contains("\"mat\""))
	# blend off = classic behaviour
	_fresh(placed)
	var classic := AutoTile.new(placed)
	classic.apply(_block(origin, 3, 3), "grass")
	classic.apply([origin + SE + NE], "ground")
	ck.call("blend: with Auto Blend off nothing blends and no ownership is stored", _id(placed, origin + SE + NE).begins_with("ground9_") and placed.cell_mat.is_empty())

	# three-material junctions: deterministic, fully tiled
	_fresh(placed)
	var t7 := _tiler(placed)
	var j := _block(origin, 7, 7)
	t7.apply(j, "grass")
	t7.apply(_block(origin + SE * 3.0, 4, 3), "dirt")
	t7.apply(_block(origin + SE * 3.0 + NE * 4.0, 4, 3), "rock")
	placed._changed(false)
	var j1 := {}
	for c: Vector2 in j:
		j1[c] = _id(placed, c)
	t7.apply(_block(origin + SE * 3.0, 4, 3), "dirt")
	var j_same := true
	for c: Vector2 in j:
		j_same = j_same and j1[c] == _id(placed, c)
	ck.call("blend: grass/dirt/rock junction: nothing missing", _missing(placed, j) == 0)
	ck.call("blend: grass/dirt/rock junction: deterministic", j_same)
	var junction_bad := _seam_vertices(placed, j)
	var only_junctions := true
	for v: Vector2 in junction_bad:
		var mats := {}
		for d in [Vector2(0, 18), Vector2(-36, 0), Vector2(36, 0), Vector2(0, -18), Vector2(36, 36), Vector2(-36, 36), Vector2(36, -36), Vector2(-36, -36), Vector2(72, 18), Vector2(72, -18), Vector2(-72, 18), Vector2(-72, -18)]:
			mats[String(placed.cell_mat.get(v + d, ""))] = true
		mats.erase("")
		only_junctions = only_junctions and mats.size() >= 3
	ck.call("blend: three-material junction has zero conflicting vertices", junction_bad.is_empty(), "bad=%d" % junction_bad.size())
	print("INFO exact junction seam vertices: ", junction_bad.size())
	ck.call("blend: a 4-way meeting of grass/dirt/rock/temple is tiled", _four_way(placed, origin))

	# shorelines follow the land material
	_fresh(placed)
	var t8 := _tiler(placed)
	t8.apply(_block(origin, 4, 4), "dirt")
	var wc: Vector2 = origin + SE * 4.0 + NE * 1.0
	t8.apply([wc], "water")
	placed._changed(false)
	ck.call("blend: water next to brown dirt uses the brown bank", _id(placed, wc).begins_with("shore_brown_"), _id(placed, wc))
	t8.apply(_block(origin, 4, 4), "rock")
	placed._changed(false)
	ck.call("blend: changing the nearby land to rock re-picks the rock bank", _id(placed, wc).begins_with("shore_rock_"), _id(placed, wc))
	for material: String in ["dirt","rock"]:
		_fresh(placed)
		var plain := AutoTile.new(placed)
		plain.apply(_block(origin,4,4),material)
		plain.apply([wc],"water")
		var expected_bank := "brown" if material=="dirt" else "rock"
		ck.call("blend off: native "+material+" tiles and matching animated shore",_missing(placed,_block(origin,4,4))==0 and _id(placed,wc).begins_with("shore_"+expected_bank+"_"))

	# Manual replacement, delete and clear must not leave orphan ownership or lose it on undo.
	_fresh(placed)
	var ownership := _tiler(placed)
	ownership.apply([origin],"dirt")
	placed._changed(false)
	placed.remove(placed.ground_at(origin))
	ck.call("blend: manual delete clears ownership",not placed.cell_mat.has(origin))
	ck.call("blend: undo delete restores ownership",placed.undo() and placed.cell_mat.get(origin)=="dirt")
	placed.paint_cell("grass_dirt_06_b",origin)
	placed._changed(false)
	ck.call("blend: manual replacement is persistently pinned",placed.cell_mat.get(origin)=="lock")
	placed.clear_all()
	ck.call("blend: clear removes all ownership",placed.cell_mat.is_empty())
	ck.call("blend: undo clear restores pinned ownership",placed.undo() and placed.cell_mat.get(origin)=="lock" and _id(placed,origin)=="grass_dirt_06_b")
	ck.call("blend: redo clear removes ownership",placed.redo() and placed.cell_mat.is_empty())
	var tiles_tab := true
	for category: Array in PlacedObjects.CATEGORIES:
		if not category[1].is_empty() and PlacedObjects.is_floor_tile(category[1][0]):
			tiles_tab=tiles_tab and AssetBrowser.tab_of(category[0])=="tiles"
	ck.call("blend: every flat material and junction category is in TILES",tiles_tab)
	main.queue_free()
	await tree.process_frame
	MapEditorMode.forced = previous_map_mode


func _four_way(placed: PlacedObjects, origin: Vector2) -> bool:
	_fresh(placed)
	var t := _tiler(placed)
	var cells := _block(origin, 6, 6)
	t.apply(_block(origin, 3, 3), "grass")
	t.apply(_block(origin + SE * 3.0, 3, 3), "dirt")
	t.apply(_block(origin + NE * 3.0, 3, 3), "rock")
	t.apply(_block(origin + SE * 3.0 + NE * 3.0, 3, 3), "temple")
	placed._changed(false)
	return _missing(placed, cells) == 0
