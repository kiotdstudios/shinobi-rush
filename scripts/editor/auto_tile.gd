class_name AutoTile
extends RefCounted
## Builder auto-tiling. Paint WATER / GRASS / GROUND / TEMPLE as a plain area and every touched floor cell (and the
## ring of cells around it) picks the right edge, corner or bank piece on its own.
##   land cells  : 9-piece set (edge_ne ... corner_bottom); an edge shows only where the floor ends in the void.
##   water cells : bank piece `shore_<family>_NN` (16 corner masks) whenever land is nearby, else water9 pieces.
## Nothing here commits: callers run one `placed._changed()` per gesture so a whole drag is one undo step.

const TERRAINS: Array[String] = ["water", "grass", "ground", "temple", "dirt", "rock"]
const PREFIX := {"water": "water9", "grass": "grass9", "ground": "ground9", "temple": "temple_floor", "dirt": "path_dirt", "rock": "grass_rock"}
const BANK_FAMILIES: Array[String] = ["", "grass", "dirt", "rock"]  ## "" = follow the neighbouring land
const BASE_ID := {"water": "water9_center", "grass": "grass9_center", "ground": "ground9_center", "temple": "temple_floor_center", "dirt": "path_dirt_15_a", "rock": "grass_rock_00_a"}
## Cells that share a corner with a cell: its 4 edge neighbours plus the 4 cells two steps away along the axes.
const RING: Array[Vector2] = [Vector2(36, -18), Vector2(-36, -18), Vector2(36, 18), Vector2(-36, 18), Vector2(0, -36), Vector2(0, 36), Vector2(72, 0), Vector2(-72, 0)]
## Every cell whose corner materials can change when one cell changes (a vertex looks 3 cells out), 25 cells.
static var BLEND_REACH: Array[Vector2] = _build_reach()
const NE := Vector2(36, -18)
const NW := Vector2(-36, -18)
const SE := Vector2(36, 18)
const SW := Vector2(-36, 18)
const BIT_TOP := 8
const BIT_RIGHT := 4
const BIT_LEFT := 2
const BIT_BOTTOM := 1

static func _build_reach() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in range(-3, 4):
		for m in range(-3, 4):
			if posmod(k + m, 2) == 0:
				out.append(Vector2(36 * k, 18 * m))
	return out


var placed: PlacedObjects
var bank_family := ""  ## "" | "grass" | "dirt" | "rock": forces the bank look for new shore pieces
var _map: Dictionary = {}  ## floor-cell centre -> tile id (one tile per cell)
var changed := 0
## Material-aware blending (corner-mask transition tiles between grass / ground / dirt / temple / rock). Off keeps the
## classic behaviour byte-for-byte; the builder turns it on with its Auto Blend toggle.
var blend := false


func _init(p: PlacedObjects, bank := "") -> void:
	placed = p
	bank_family = bank
	for o in p.objects:
		if PlacedObjects.is_floor_tile(o.id):
			_map[PlacedObjects.lattice_center(o.pos as Vector2)] = String(o.id)


## "water" | "grass" | "ground" | "temple" for tiles auto-tiling manages, "land" for any other floor tile, "" for none.
static func terrain_of(id: String) -> String:
	if id == "":
		return ""
	if id.begins_with("water9_"):
		return "water"
	if id.begins_with("shore_"):
		return "land" if shore_mask_of(id) == 15 else "water"
	if id.begins_with("grass9_"):
		return "grass"
	if id.begins_with("ground9_"):
		return "ground"
	if id.begins_with("temple_floor_"):
		return "temple"
	return "land" if PlacedObjects.is_floor_tile(id) else ""


static func shore_mask_of(id: String) -> int:
	return int(PlacedObjects.def_of(id).get("shore_mask", -1))


static func shore_family_of(id: String) -> String:
	return String(PlacedObjects.def_of(id).get("shore_family", ""))


static func is_shore(id: String) -> bool:
	return id.begins_with("shore_")


func terrain_at(cell: Vector2) -> String:
	if blend:
		var m := mat_at(cell)
		if m != "":
			return m
	return terrain_of(String(_map.get(cell, "")))


## The material the owner painted on `cell` ("" when unmanaged, locked or empty).
func mat_at(cell: Vector2) -> String:
	if not _map.has(cell):
		return ""
	var m := String(placed.cell_mat.get(cell, ""))
	return m if m in TerrainBlend.MATERIALS else ""


func is_locked(cell: Vector2) -> bool:
	return _map.has(cell) and String(placed.cell_mat.get(cell, "")) == "lock"


## Manual override: a locked cell keeps its tile and is never retiled (its corners pin the neighbours instead).
func lock(cell: Vector2) -> void:
	if _map.has(cell):
		placed.set_cell_mat(cell, "lock")


## Hand the cell back to auto-blend (only pure tiles carry a material; a mixed tile stays a pinned manual piece).
func unlock(cell: Vector2) -> void:
	if not is_locked(cell):
		return
	var pm := TerrainBlend.pure_material(id_at(cell))
	placed.set_cell_mat(cell, pm)
	if pm != "":
		retile(cell)


const VERTEX_FAR: Array[Vector2] = [Vector2(36, 36), Vector2(-36, 36), Vector2(36, -36), Vector2(-36, -36), Vector2(72, 18), Vector2(72, -18), Vector2(-72, 18), Vector2(-72, -18)]


## Vertex material shared by the (up to) 4 cells touching a vertex. The material owning the FEWEST of those cells wins
## (so a thin trail, an island or a hole keeps its own colour instead of being swallowed); a tie is broken by the
## fewest in the 8 cells around them (a 1-wide trail ties 2:2 locally but is the minority nearby), and a remaining tie
## goes to the higher TerrainBlend priority. A pinned tile (manual / unmanaged mixed art) always wins its own corner
## so hand art is never contradicted.
func raw_vertex_mat(v: Vector2) -> String:
	var cells: Array[Vector2] = [v + Vector2(0, 18), v + Vector2(-36, 0), v + Vector2(36, 0), v + Vector2(0, -18)]
	var count := {}
	var pin := ""
	for i in 4:
		var c := cells[i]
		var m := mat_at(c)
		if m != "":
			count[m] = int(count.get(m, 0)) + 1
			continue
		var sig := TerrainBlend.signature_of(id_at(c))
		if sig.size() == 4:
			pin = TerrainBlend.higher(pin, sig[i])
	if pin != "":
		return pin
	if count.size() <= 1:
		return String(count.keys()[0]) if count.size() == 1 else ""
	var far := {}
	for d in VERTEX_FAR:
		var m2 := mat_at(v + d)
		if m2 != "":
			far[m2] = int(far.get(m2, 0)) + 1
	var best := ""
	for m: String in count:
		if best == "":
			best = m
			continue
		var cm := int(count[m])
		var cb := int(count[best])
		var fm := int(far.get(m, 0))
		var fb := int(far.get(best, 0))
		if cm < cb or (cm == cb and (fm < fb or (fm == fb and TerrainBlend.higher(m, best) == m))):
			best = m
	return best


## raw_vertex_mat(), except at a junction of 3+ materials: there the candidate that leaves every touching tile
## drawable with ONE two-material kit (<= 2 materials per tile, and a registered pair) wins, so the seam stays continuous.
func vertex_mat(v: Vector2) -> String:
	var raw := raw_vertex_mat(v)
	if raw == "":
		return raw
	var cells: Array[Vector2] = [v + Vector2(0, 18), v + Vector2(-36, 0), v + Vector2(36, 0), v + Vector2(0, -18)]
	var owners: Array[String] = []
	for c in cells:
		var m := mat_at(c)
		if m != "" and m not in owners:
			owners.append(m)
	if owners.size() < 3:
		return raw
	var best := raw
	var best_bad := _bad_cells(v, cells, raw)
	for cand in owners:
		if cand == raw or best_bad == 0:
			continue
		var bad := _bad_cells(v, cells, cand)
		if bad < best_bad:
			best = cand
			best_bad = bad
	return best


## How many of the 4 tiles around `v` could not be drawn if `v` showed `cand` (raw value for their other corners).
func _bad_cells(v: Vector2, cells: Array[Vector2], cand: String) -> int:
	var bad := 0
	var idx_off: Array[Vector2] = [Vector2(0, -18), Vector2(36, 0), Vector2(-36, 0), Vector2(0, 18)]
	for i in 4:
		if mat_at(cells[i]) == "":
			continue
		var present: Array[String] = []
		for j in 4:
			var vv := cells[i] + idx_off[j]
			var m := cand if vv == v else raw_vertex_mat(vv)
			if m != "" and m not in present:
				present.append(m)
		if present.size() > 2 or (present.size() == 2 and TerrainBlend.pair_family(present[0], present[1]) == ""):
			bad += 1
	return bad


## [top, right, left, bottom] materials the cell's four corners should show.
func corners_of(cell: Vector2) -> Array:
	return [vertex_mat(cell + Vector2(0, -18)), vertex_mat(cell + Vector2(36, 0)), vertex_mat(cell + Vector2(-36, 0)), vertex_mat(cell + Vector2(0, 18))]


func id_at(cell: Vector2) -> String:
	return String(_map.get(cell, ""))


func _is_land(cell: Vector2) -> bool:
	var t := terrain_at(cell)
	return t != "" and t != "water"


## Paint `terrain` ("" clears) over `cells`, then re-pick every touched piece. Returns how many tiles changed.
func apply(cells: Array, terrain: String) -> int:
	changed = 0
	var touched := {}
	for cell: Vector2 in cells:
		if not _set_cell(cell, terrain):
			continue
		touched[cell] = true
	var ring := {}
	for cell: Vector2 in touched:
		ring[cell] = true
		for d in RING:
			ring[cell + d] = true
	if blend:
		for cell: Vector2 in ring:
			_adopt(cell)
		var wide := {}
		for cell: Vector2 in touched:
			for d in BLEND_REACH:
				wide[cell + d] = true
		for cell: Vector2 in wide:
			ring[cell] = true
	for cell: Vector2 in ring:
		retile(cell)
	return changed


## Legacy pure floor art next to a deliberate edit joins auto-blend (a mixed tile never does: it stays a manual piece).
func _adopt(cell: Vector2) -> void:
	if not _map.has(cell) or placed.cell_mat.has(cell):
		return
	var pm := TerrainBlend.pure_material(id_at(cell))
	if pm != "":
		placed.set_cell_mat(cell, pm)


## Remove one floor tile object and re-pick the pieces around it.
func erase(obj: Dictionary) -> void:
	var cell := PlacedObjects.lattice_center(obj.pos as Vector2)
	apply([cell], "")


func _set_cell(cell: Vector2, terrain: String) -> bool:
	if terrain == "":
		var old := placed.floor_tiles_in_cell(cell)
		if old.is_empty():
			return false
		for o in old:
			if placed.type_locked(o.id):
				return false
		for o in old:
			placed.remove(o, false)
		_map.erase(cell)
		placed.set_cell_mat(cell, "")
		changed += 1
		return true
	var owned := terrain in TerrainBlend.MATERIALS
	if terrain_at(cell) == terrain and not is_locked(cell):
		if blend and owned:
			placed.set_cell_mat(cell, terrain)
		return true  # already that terrain: keep the piece, the retile pass re-picks it
	var base: String = BASE_ID[terrain]
	if not _lay(base, cell):
		return false
	_map[cell] = base
	placed.set_cell_mat(cell, terrain if (blend and owned) else "")
	changed += 1
	return true


func _lay(id: String, cell: Vector2) -> bool:
	placed._auto_paint = true
	var ok := placed.paint_cell(id, cell)
	placed._auto_paint = false
	return ok


## Re-pick the piece on one cell (no-op for empty cells and for hand-placed floor art that is not managed).
func retile(cell: Vector2) -> void:
	if blend and mat_at(cell) != "":
		_retile_managed(cell)
		return
	var cur := id_at(cell)
	var t := terrain_of(cur)
	if t == "" or t == "land":
		return
	var want := pick(cell, cur, t)
	if want == "" or want == cur:
		return
	if _lay(want, cell):
		_map[cell] = want
		changed += 1


func _retile_managed(cell: Vector2) -> void:
	var cur := id_at(cell)
	var own := mat_at(cell)
	var res := TerrainBlend.resolve(own, corners_of(cell))
	var want := ""
	if res.has("pure"):
		var shown: String = res.pure
		if TerrainBlend.pure_material(cur) == shown:
			want = pick(cell, cur, shown) if shown in PREFIX else cur
		else:
			want = pick(cell, "", shown) if shown in PREFIX and shown != "dirt" and shown != "rock" else TerrainBlend.tile_id(res, cell)
	else:
		var t := TerrainBlend.parse_transition(cur)
		if not t.is_empty() and t.family == res.family and int(t.mask) == int(res.mask):
			want = cur  # keep the variant already drawn
		else:
			want = TerrainBlend.tile_id(res, cell)
	if want == "" or want == cur:
		return
	if _lay(want, cell):
		_map[cell] = want
		changed += 1


## The piece that belongs on `cell` given its neighbours. `cur` (its current tile) keeps variants and bank style stable.
func pick(cell: Vector2, cur: String, t: String) -> String:
	if t == "water":
		var mask := corner_mask(cell)
		if mask != 0:
			if mask == 15:
				mask = 14  # a pond cell with land on every side stays water
			return "shore_%s_%02d" % [_bank_for(cell, cur), mask]
	var prefix: String = PREFIX[t]
	var role := role_for(cell)
	if role == "center" and terrain_of(cur) == t and not is_shore(cur) and cur.begins_with(prefix + "_") and not _is_edge_id(cur):
		return cur  # keep a temple floor's cracked / mossy variant
	return "%s_%s" % [prefix, role]


static func _is_edge_id(id: String) -> bool:
	return id.contains("_edge_") or id.contains("_corner_")


## Land bits for a water cell's four corners (top 8, right 4, left 2, bottom 1): a corner is land when any cell touching it is.
func corner_mask(cell: Vector2) -> int:
	var mask := 0
	if _is_land(cell + NE) or _is_land(cell + NW) or _is_land(cell + Vector2(0, -36)):
		mask |= BIT_TOP
	if _is_land(cell + NE) or _is_land(cell + SE) or _is_land(cell + Vector2(72, 0)):
		mask |= BIT_RIGHT
	if _is_land(cell + NW) or _is_land(cell + SW) or _is_land(cell + Vector2(-72, 0)):
		mask |= BIT_LEFT
	if _is_land(cell + SE) or _is_land(cell + SW) or _is_land(cell + Vector2(0, 36)):
		mask |= BIT_BOTTOM
	return mask


## "center" | "edge_ne" ... | "corner_top" ...: which sides of the cell have no floor next to them.
func role_for(cell: Vector2) -> String:
	var ne := not _has_floor(cell + NE)
	var nw := not _has_floor(cell + NW)
	var se := not _has_floor(cell + SE)
	var sw := not _has_floor(cell + SW)
	if ne and nw:
		return "corner_top"
	if ne and se:
		return "corner_right"
	if se and sw:
		return "corner_bottom"
	if nw and sw:
		return "corner_left"
	if ne:
		return "edge_ne"
	if nw:
		return "edge_nw"
	if se:
		return "edge_se"
	if sw:
		return "edge_sw"
	return "center"


func _has_floor(cell: Vector2) -> bool:
	return _map.has(cell)


func _bank_for(cell: Vector2, cur: String) -> String:
	if bank_family != "":
		return bank_family
	if is_shore(cur):
		return shore_family_of(cur)
	for d in [NW, NE, SW, SE, Vector2(0, -36), Vector2(0, 36), Vector2(72, 0), Vector2(-72, 0)]:
		match terrain_at(cell + d):
			"grass":
				return "grass"
			"ground":
				return "dirt"
			"temple", "rock":
				return "rock"
			"dirt":
				return "dirt"
			"land":
				var id := id_at(cell + d)
				if is_shore(id):
					return shore_family_of(id)
	return "grass"
