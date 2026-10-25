class_name TagBombArt
extends RefCounted
## Native, centered 128px item frames; body, glow and detonation are separate layers.
static var _cache: Dictionary = {}

static func frames(kind: String, layer: String) -> Array:
	var key := kind + "/" + layer
	if _cache.has(key):
		return _cache[key]
	var result: Array = []
	var base := "res://assets/pickups/" + kind + "/"
	var i := 0
	while ResourceLoader.exists(base + "%s_%02d.png" % [layer, i]):
		result.append(load(base + "%s_%02d.png" % [layer, i]))
		i += 1
	_cache[key] = result
	return result
