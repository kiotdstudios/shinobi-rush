class_name TerrainBlend
extends RefCounted
## Material identity + corner-mask tile selection for flat-floor auto-blending.
## Logical materials: grass, ground (path), dirt, temple, rock. Every 16-corner-mask transition family registered by
## PR #230 (path_dirt) and PR #240 (the other seven) is a (zero, one) material pair: a SET corner bit shows `one`,
## an unset corner shows `zero`. Corner bits for ALL these kits: top=8, right=4, left=2, bottom=1 (NOT PR #226's
## dirt16 *edge* bits, which are a different convention and are never used here).

const MATERIALS: Array[String] = ["grass", "ground", "dirt", "temple", "rock"]
## Who spreads onto whom at a shared vertex: higher wins. Grass is the background; rock is the strongest.
const PRIORITY := {"grass": 0, "temple": 1, "ground": 2, "dirt": 3, "rock": 4}
const BITS: Array[int] = [8, 4, 2, 1]  ## corner order everywhere: top, right, left, bottom
## family id -> [zero material, one material]. Manifest source: transitions.art.json / path-dirt.art.json.
const FAMILIES := {
	"path_dirt": ["ground", "dirt"],
	"path_temple": ["temple", "ground"],
	"path_rock": ["rock", "ground"],
	"grass_path": ["ground", "grass"],
	"grass_temple": ["temple", "grass"],
	"dirt_temple": ["temple", "dirt"],
	"grass_rock": ["rock", "grass"],
	"dirt_rock": ["rock", "dirt"],
	"temple_rock": ["rock", "temple"],
	"grass_dirt": ["dirt", "grass"],
}
## A pure (all four corners) tile per material, used when a cell has no neighbour to blend with.
const PURE_ID := {"grass": "grass9_center", "ground": "ground9_center", "dirt": "path_dirt_15_a", "temple": "temple_floor_center", "rock": "grass_rock_00_a"}
const PURE_PREFIX := {"grass": "grass9_", "ground": "ground9_", "temple": "temple_floor_"}

static var _pair_family: Dictionary = {}


static func pair_family(a: String, b: String) -> String:
	if _pair_family.is_empty():
		for fid: String in FAMILIES:
			var f: Array = FAMILIES[fid]
			_pair_family["%s|%s" % [f[0], f[1]]] = fid
			_pair_family["%s|%s" % [f[1], f[0]]] = fid
	return String(_pair_family.get("%s|%s" % [a, b], ""))


static func higher(a: String, b: String) -> String:
	if a == "":
		return b
	if b == "":
		return a
	return a if int(PRIORITY[a]) >= int(PRIORITY[b]) else b


static func parse_transition(id: String) -> Dictionary:
	## {family, mask, variant} for ids like grass_dirt_06_b, else {}.
	var n := id.length()
	if n < 7 or id[n - 2] != "_" or id[n - 5] != "_":
		return {}
	var v := id.substr(n - 1)
	var m := id.substr(n - 4, 2)
	var fid := id.substr(0, n - 5)
	if not FAMILIES.has(fid) or not m.is_valid_int() or v not in ["a", "b", "c"]:
		return {}
	var mask := m.to_int()
	if mask < 0 or mask > 15:
		return {}
	return {"family": fid, "mask": mask, "variant": v}


## Material at each corner [top, right, left, bottom] of a known floor tile, or [] (shores, props, unknown art).
static func signature_of(id: String) -> Array:
	if id.begins_with("junction_"):
		var parts := id.split("_")
		if parts.size() != 5:
			return []
		var corners: Array = []
		for i in range(1, 5):
			if not parts[i].is_valid_int():
				return []
			var index := int(parts[i])
			if index < 0 or index >= MATERIALS.size():
				return []
			corners.append(MATERIALS[index])
		return corners
	for mat: String in PURE_PREFIX:
		if id.begins_with(PURE_PREFIX[mat]):
			return [mat, mat, mat, mat]
	var t := parse_transition(id)
	if t.is_empty():
		return []
	var f: Array = FAMILIES[t.family]
	var out: Array = []
	for bit in BITS:
		out.append(f[1] if (int(t.mask) & bit) != 0 else f[0])
	return out


## The single material of a tile whose four corners agree, else "".
static func pure_material(id: String) -> String:
	var s := signature_of(id)
	if s.size() == 4 and s[0] == s[1] and s[1] == s[2] and s[2] == s[3]:
		return s[0]
	return ""


## Reduce four wanted corner materials to something one registered tile can show.
## Returns {"pure": material} or {"family": id, "mask": 0..15}. `own` is the cell's own material (kept when possible).
## Exactly three materials use the registered exact-corner junction kit. Four distinct materials
## have no authored kit and fall back deterministically: the cell keeps its own
## material plus the highest-priority partner that has a family; every other corner shows the lead material.
static func resolve(own: String, corners: Array) -> Dictionary:
	var present: Array[String] = []
	for c: String in corners:
		if c != "" and c not in present:
			present.append(c)
	if present.size() <= 1:
		return {"pure": present[0] if present.size() == 1 else own}
	if present.size() == 3:
		var junction := TerrainJunctionArt.tile_id(corners)
		if junction != "" and not PlacedObjects.def_of(junction).is_empty():
			return {"junction": junction}
	present.sort_custom(func(a: String, b: String) -> bool:
		if (a == own) != (b == own):
			return a == own
		return int(PRIORITY[a]) > int(PRIORITY[b]))
	var lead := present[0]
	var partner := ""
	for other in present.slice(1):
		if pair_family(lead, other) != "":
			partner = other
			break
	if partner == "":
		return {"pure": lead}
	var fid := pair_family(lead, partner)
	var one: String = FAMILIES[fid][1]
	var mask := 0
	for i in 4:
		var m: String = corners[i] if (corners[i] == lead or corners[i] == partner) else lead
		if m == one:
			mask |= BITS[i]
	return {"family": fid, "mask": mask}


## Stable A/B/C pick for a cell: the same cell always draws the same variant (repaint, reload, undo).
static func variant_for(cell: Vector2, reroll := 0) -> String:
	var h := int(roundf(cell.x / 36.0)) * 73856093 ^ int(roundf(cell.y / 18.0)) * 19349663 ^ reroll * 83492791
	return ["a", "b", "c"][posmod(h, 3)]


static func tile_id(res: Dictionary, cell: Vector2) -> String:
	if res.has("junction"):
		return String(res.junction)
	if res.has("pure"):
		return PURE_ID[res.pure]
	var mask: int = res.mask
	var v := "a" if (mask == 0 or mask == 15) else variant_for(cell)
	return "%s_%02d_%s" % [res.family, mask, v]
