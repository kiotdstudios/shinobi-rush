class_name TerrainFamilyMatcher
extends RefCounted
## Metadata-first suggestions for incoming 72x36 flat isometric tiles.
## Suggestions never modify the approved TerrainBlend registry.
const SIZE := Vector2i(72, 36)
const MATERIALS := ["grass", "ground", "dirt", "temple", "rock"]
const MIN_CONFIDENCE := 0.72

static func approved_family(id: String) -> String:
	var signature := TerrainBlend.signature_of(id)
	if signature.size() == 4:
		var unique := {}
		for mat in signature:
			unique[mat] = true
		if unique.size() == 1:
			return String(unique.keys()[0])
		if unique.size() == 2:
			var keys := unique.keys()
			return TerrainBlend.pair_family(String(keys[0]), String(keys[1]))
		if unique.size() == 3:
			return "junction"
	return ""

static func suggest(id: String, texture: Texture2D, metadata: Dictionary = {}) -> Dictionary:
	var image := texture.get_image() if texture != null else null
	if image == null or image.get_size() != SIZE:
		return {"approved": false, "reason": "Expected native 72x36 isometric tile"}
	var family := String(metadata.get("terrain_family", ""))
	if family == "":
		family = approved_family(id)
	if family != "":
		return {"approved": false, "family": family, "confidence": 1.0, "reason": "Known registry/metadata; approval still required"}
	var features := edge_features(image)
	var best := ""
	var best_score := 0.0
	for mat in MATERIALS:
		var sample_id: String = TerrainBlend.PURE_ID[mat]
		var definition := PlacedObjects.def_of(sample_id)
		var path := String(definition.get("texture", definition.get("path", "")))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var ref_texture := load(path) as Texture2D
		if ref_texture == null:
			continue
		var ref_features := edge_features(ref_texture.get_image())
		var score := similarity(features, ref_features)
		if score > best_score:
			best_score = score
			best = mat
	return {"approved": false, "family": best, "confidence": best_score, "reason": "Visual suggestion only; confirm material and corner polarity"}

static func edge_features(image: Image) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if image.get_size() != SIZE:
		return out
	for edge in range(4):
		var sum := Vector3.ZERO
		var count := 0
		for i in range(19):
			var x := i * 4 if edge < 2 else (i * 4 if edge == 2 else 71 - i * 4)
			var y := 0 if edge == 0 else (35 if edge == 1 else 18)
			var c := image.get_pixel(clampi(x, 0, 71), y)
			if c.a < 0.5:
				continue
			sum += Vector3(c.r, c.g, c.b)
			count += 1
		var avg := sum / float(maxi(1, count))
		out.append_array([avg.x, avg.y, avg.z, float(count) / 19.0])
	return out

static func similarity(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != 16 or b.size() != 16:
		return 0.0
	var delta := 0.0
	for i in range(16):
		delta += absf(a[i] - b[i])
	return clampf(1.0 - delta / 16.0, 0.0, 1.0)

static func approve(suggestion: Dictionary, overrides: Dictionary, tile_id: String) -> Dictionary:
	var family := String(suggestion.get("family", ""))
	if family == "" or float(suggestion.get("confidence", 0.0)) < MIN_CONFIDENCE:
		return overrides
	var copy := overrides.duplicate(true)
	copy[tile_id] = family
	return copy
