class_name TerrainJunctionArt
extends RefCounted
## Art lookup only. Aki owns vertex voting, managed ownership, and auto placement.
const MATERIALS := ["grass", "ground", "dirt", "temple", "rock"]
const MANIFEST := "res://assets/environment/blightwood/terrain_junctions/junctions.art.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _data

static func tile_id(corners: Array) -> String:
	if corners.size() != 4:
		return ""
	var distinct := {}
	var parts: PackedStringArray = []
	for material: String in corners:
		var index := MATERIALS.find(material)
		if index < 0:
			return ""
		distinct[material] = true
		parts.append(str(index))
	if distinct.size() == 3:
		return "junction_" + "_".join(parts)
	if distinct.size() > 3:
		return "" # Four distinct materials need a separate extension; never silently drop a corner.
	for pair: Dictionary in data().pairs:
		if not distinct.has(pair.zero) and not distinct.has(pair.one):
			continue
		var mask := 0
		var valid := true
		for i in 4:
			valid = valid and corners[i] in [pair.zero, pair.one]
			if corners[i] == pair.one:
				mask |= [8,4,2,1][i]
		if valid:
			return "%s_%02d_a" % [pair.id,mask]
	return ""
