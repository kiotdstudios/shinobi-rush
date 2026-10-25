class_name AutoTile
extends RefCounted
## Builder auto-tiling. Paint WATER / GRASS / GROUND / TEMPLE as a plain area and every touched floor cell (and the
## ring of cells around it) picks the right edge, corner or bank piece on its own.
##   land cells  : 9-piece set (edge_ne ... corner_bottom); an edge shows only where the floor ends in the void.
##   water cells : bank piece `shore_<family>_NN` (16 corner masks) whenever land is nearby, else water9 pieces.
## Nothing here commits: callers run one `placed._changed()` per gesture so a whole drag is one undo step.

const TERRAINS: Array[String] = ["water", "grass", "ground", "temple"]
const PREFIX := {"water": "water9", "grass": "grass9", "ground": "ground9", "temple": "temple_floor"}
const BANK_FAMILIES: Array[String] = ["", "grass", "dirt", "rock"]  ## "" = follow the neighbouring land
const BASE_ID := {"water": "water9_center", "grass": "grass9_center", "ground": "ground9_center", "temple": "temple_floor_center"}
## Cells that share a corner with a cell: its 4 edge neighbours plus the 4 cells two steps away along the axes.
const RING: Array[Vector2] = [Vector2(36, -18), Vector2(-36, -18), Vector2(36, 18), Vector2(-36, 18), Vector2(0, -36), Vector2(0, 36), Vector2(72, 0), Vector2(-72, 0)]
const NE := Vector2(36, -18)
const NW := Vector2(-36, -18)
const SE := Vector2(36, 18)
const SW := Vector2(-36, 18)
const BIT_TOP := 8
const BIT_RIGHT := 4
const BIT_LEFT := 2
const BIT_BOTTOM := 1

var placed: PlacedObjects
var bank_family := ""  ## "" | "grass" | "dirt" | "rock": forces the bank look for new shore pieces
var _map: Dictionary = {}  ## floor-cell centre -> tile id (one tile per cell)
var changed := 0


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
	return terrain_of(String(_map.get(cell, "")))


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
	for cell: Vector2 in ring:
		retile(cell)
	return changed


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
		changed += 1
		return true
	if terrain_at(cell) == terrain:
		return true  # already that terrain: keep the piece, the retile pass re-picks it
	var base: String = BASE_ID[terrain]
	if not placed.paint_cell(base, cell):
		return false
	_map[cell] = base
	changed += 1
	return true


## Re-pick the piece on one cell (no-op for empty cells and for hand-placed floor art that is not managed).
func retile(cell: Vector2) -> void:
	var cur := id_at(cell)
	var t := terrain_of(cur)
	if t == "" or t == "land":
		return
	var want := pick(cell, cur, t)
	if want == "" or want == cur:
		return
	if placed.paint_cell(want, cell):
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
			"temple":
				return "rock"
			"land":
				var id := id_at(cell + d)
				if is_shore(id):
					return shore_family_of(id)
	return "grass"
