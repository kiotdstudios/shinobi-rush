class_name SpriteLibrary
extends RefCounted
## Discovers every `*.manifest.json` under res://assets/characters/ (recursive) and parses it into a
## SpriteSet. Problems are collected as readable messages and also pushed to the console as warnings.
## Nothing is loaded from disk beyond the manifests until an animation is first used (lazy).

const ROOT := "res://assets/characters"
const SUFFIX := ".manifest.json"

static var _instance: SpriteLibrary

var sets: Array[SpriteSet] = []


static func get_instance() -> SpriteLibrary:
	if _instance == null:
		_instance = SpriteLibrary.new()
		_instance.scan()
	return _instance


## Manifest paths under `root`. Strips the .remap / .import suffixes DirAccess reports in exports.
static func discover_paths(root: String = ROOT) -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	out.sort()
	return out


static func _walk(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	if da.file_exists(".gdignore") and dir != ROOT:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if da.current_is_dir():
			if not name.begins_with("."):
				_walk(dir.path_join(name), out)
		else:
			var clean := name.trim_suffix(".remap").trim_suffix(".import")
			if clean.ends_with(SUFFIX):
				var p := dir.path_join(clean)
				if not out.has(p):
					out.append(p)
		name = da.get_next()
	da.list_dir_end()


func scan(root: String = ROOT) -> void:
	sets.clear()
	var ids: Dictionary = {}
	for path in discover_paths(root):
		var text := FileAccess.get_file_as_string(path)
		var s := SpriteSet.parse(text, path)
		if ids.has(s.id):
			s.errors.append("duplicate set id \"%s\" (also in %s)" % [s.id, ids[s.id]])
		else:
			ids[s.id] = path
		for e in s.errors:
			push_warning("SpriteLibrary: %s: %s" % [path, e])
		sets.append(s)
	sets.sort_custom(func(a: SpriteSet, b: SpriteSet) -> bool: return a.id < b.id)


func first_valid() -> SpriteSet:
	for s in sets:
		if s.is_valid():
			return s
	return null


func get_set(id: String) -> SpriteSet:
	for s in sets:
		if s.id == id:
			return s
	return null


## Exact status text shown on screen for the selected set (null = placeholder).
static func status_line(s: SpriteSet, fallback_problem: String = "") -> String:
	if s == null:
		if fallback_problem.is_empty():
			return "SPRITES: none (placeholder)"
		return "SPRITES: ERROR: " + fallback_problem
	if s.is_valid():
		return "SPRITES: %s %dx%d OK" % [s.id, s.frame_size.x, s.frame_size.y]
	return "SPRITES: %s ERROR: %s" % [s.id, s.first_error()]
