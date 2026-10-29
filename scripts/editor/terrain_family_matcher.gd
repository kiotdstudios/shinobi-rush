class_name TerrainFamilyMatcher
extends RefCounted
## Metadata wins. Pixels only rank suggestions; they never authorize a material.
const MANUAL := "manual"
static var _features: Dictionary = {}

static func metadata(id: String) -> Dictionary:
	if not PlacedObjects.is_floor_tile(id):
		return {}
	var def := PlacedObjects.def_of(id)
	var explicit := String(def.get("terrain_material", ""))
	if explicit in AutoTile.TERRAINS:
		return {"material": explicit, "source": "catalog", "materials": [explicit]}
	if int(def.get("shore_mask",-1)) == 15:
		var land := {"grass":"grass","dirt":"ground","brown":"dirt","rock":"rock"}
		var bank := String(def.get("shore_family",""))
		if land.has(bank): return {"material":land[bank],"materials":[land[bank]],"source":"shore metadata"}
	var sig := TerrainBlend.signature_of(id)
	if sig.size() == 4:
		var materials: Array = []
		for m in sig:
			if m not in materials: materials.append(m)
		return {"material": materials[0] if materials.size() == 1 else "", "materials": materials, "source": "terrain registry", "corners": sig}
	var terrain := AutoTile.terrain_of(id)
	if terrain in AutoTile.TERRAINS:
		return {"material": terrain, "materials": [terrain], "source": "auto-tile registry"}
	return {}

static func material(id: String, overrides: Dictionary) -> String:
	if not PlacedObjects.is_floor_tile(id): return ""
	if overrides.has(id):
		var chosen := String(overrides[id])
		return chosen if chosen in AutoTile.TERRAINS else ""
	return String(metadata(id).get("material", ""))

static func image_for(id: String) -> Image:
	if not PlacedObjects.is_floor_tile(id): return null
	var def := PlacedObjects.def_of(id)
	if def.has("water_role") or def.has("shore_mask"): return null
	var texture: Texture2D
	if def.get("kind", "") == "grass":
		texture = load(WindGrassTileset.DIR + id + ".png") as Texture2D
	else:
		texture = PlacedObjects.ground_texture(id)
	return texture.get_image() if texture != null else null

## Sample the native 72x36 diamond, allowing the existing grass canvas/foot anchor.
## Four separate edge colors prevent equal average colors from hiding incompatible edges.
static func features(img: Image) -> Dictionary:
	if img == null: return {}
	var origin := Vector2i.ZERO
	if img.get_size() == Vector2i(112,112): origin = Vector2i(20,66)
	elif img.get_size() != Vector2i(72,36): return {}
	var sums: Array[Color] = [Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0)]
	var counts := [0,0,0,0,0]
	for y in range(1,35,2):
		for x in range(1,71,2):
			var dx := (float(x)+.5-36.0)/36.0
			var dy := (float(y)+.5-18.0)/18.0
			var distance := absf(dx)+absf(dy)
			if distance > .94: continue
			var c := img.get_pixelv(origin+Vector2i(x,y))
			if c.a < .5: continue
			sums[0] += c
			counts[0] += 1
			if distance > .58:
				var edge := 1 + (1 if dx > 0 else 0) + (2 if dy > 0 else 0)
				sums[edge] += c
				counts[edge] += 1
	for i in 5:
		if counts[i] < 4: return {}
		sums[i] /= float(counts[i])
	return {"colors": sums}

static func similarity(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty(): return 0.0
	var error := 0.0
	for i in 5:
		var ca: Color = a.colors[i]
		var cb: Color = b.colors[i]
		error += (absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b))/3.0
	return clampf(1.0-error/5.0,0.0,1.0)

static func _feature(id: String) -> Dictionary:
	if not _features.has(id): _features[id] = features(image_for(id))
	return _features[id]

static func suggestions(id: String) -> Array:
	var target := _feature(id)
	if target.is_empty(): return []
	var out: Array = []
	for m: String in TerrainBlend.MATERIALS:
		out.append({"material":m,"score":similarity(target,_feature(TerrainBlend.PURE_ID[m]))})
	out.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.material < b.material if is_equal_approx(a.score,b.score) else a.score > b.score)
	return out
