class_name SpriteSet
extends RefCounted
## One sprite set = one parsed `*.manifest.json` (schema v1). Parsing is tolerant: unknown keys are
## ignored and every problem becomes a readable message in `errors` (never a crash).
## Textures are built lazily per animation on first use and cached (see get_frames).

const DIRS8: Array[String] = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const OCTANT_DIRS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]  ## indexed by angle / 45 degrees (y down)
const DEFAULT_FPS := 24.0
const DEFAULT_BODY_HEIGHT := 108.0

var id: String = ""
var manifest_path: String = ""
var base_dir: String = ""
var frame_size: Vector2i = Vector2i.ZERO
var foot_anchor: Vector2 = Vector2.ZERO
var body_height_px: float = DEFAULT_BODY_HEIGHT
var directions: Array[String] = []
var mirror: Dictionary = {}  ## target direction -> source direction (flipped horizontally)
var animations: Dictionary = {}  ## anim id -> normalized definition (see _parse_animation)
var anim_order: Array[String] = []
var errors: Array[String] = []

var anims_loaded: int = 0
var frames_loaded: int = 0
var load_ms: float = 0.0
var _cache: Dictionary = {}  ## anim id -> SpriteFrames


func is_valid() -> bool:
	return errors.is_empty()


func first_error() -> String:
	return errors[0] if not errors.is_empty() else ""


func _err(msg: String) -> void:
	errors.append(msg)


## Load-time problem (found while building frames): recorded once per distinct message and also
## sent to the console, so it shows in the browser console as well as in the HUD.
func _load_err(msg: String) -> void:
	if errors.has(msg):
		return
	errors.append(msg)
	push_warning("SpriteSet: %s: %s" % [manifest_path, msg])


# ---------------------------------------------------------------- parsing

## Parse manifest text. `check_files` verifies referenced PNGs exist (source or imported).
static func parse(text: String, manifest_path: String, check_files: bool = true) -> SpriteSet:
	var s := SpriteSet.new()
	s.manifest_path = manifest_path
	s.base_dir = manifest_path.get_base_dir()
	s.id = manifest_path.get_file().trim_suffix(".manifest.json")
	var json := JSON.new()
	if json.parse(text) != OK:
		s._err("invalid JSON (line %d): %s" % [json.get_error_line(), json.get_error_message()])
		return s
	if typeof(json.data) != TYPE_DICTIONARY:
		s._err("manifest root must be a JSON object")
		return s
	var d: Dictionary = json.data
	if d.has("id") and typeof(d["id"]) == TYPE_STRING and not String(d["id"]).is_empty():
		s.id = d["id"]
	if int(d.get("schema", 0)) != 1:
		s._err("unsupported or missing \"schema\" (expected 1)")
	var fs: Variant = _vec2(d.get("frame_size"))
	if fs == null or fs.x < 1 or fs.y < 1:
		s._err("\"frame_size\" must be [width, height] with positive numbers")
		return s
	s.frame_size = Vector2i(fs)
	var fa: Variant = _vec2(d.get("foot_anchor"))
	s.foot_anchor = fa if fa != null else Vector2(s.frame_size.x * 0.5, s.frame_size.y)
	if d.has("foot_anchor") and fa == null:
		s._err("\"foot_anchor\" must be [x, y]")
	if d.has("body_height_px"):
		var bh := float(d["body_height_px"])
		if bh > 0.0:
			s.body_height_px = bh
	if typeof(d.get("directions")) == TYPE_ARRAY:
		for v: Variant in d["directions"]:
			var dn := norm_dir(v)
			if dn.is_empty():
				s._err("unknown direction \"%s\" in \"directions\" (use %s)" % [str(v), ", ".join(DIRS8)])
			elif not s.directions.has(dn):
				s.directions.append(dn)
	if typeof(d.get("mirror")) == TYPE_DICTIONARY:
		for k: Variant in d["mirror"]:
			var kt := norm_dir(k)
			var vs := norm_dir(d["mirror"][k])
			if kt.is_empty() or vs.is_empty():
				s._err("bad \"mirror\" entry %s -> %s" % [str(k), str(d["mirror"][k])])
			else:
				s.mirror[kt] = vs
	if typeof(d.get("animations")) != TYPE_DICTIONARY or (d["animations"] as Dictionary).is_empty():
		s._err("\"animations\" must be an object with at least one animation")
		return s
	for aid: Variant in d["animations"]:
		s._parse_animation(String(aid), d["animations"][aid], check_files)
	s._check_cardinals()
	return s


func _parse_animation(aid: String, a: Variant, check_files: bool) -> void:
	if typeof(a) != TYPE_DICTIONARY:
		_err("animation \"%s\" must be an object" % aid)
		return
	var ad: Dictionary = a
	var fps := float(ad.get("fps", DEFAULT_FPS))
	if fps <= 0.0:
		_err("animation \"%s\": fps must be > 0" % aid)
		return
	var def := {
		"fps": fps, "loop": bool(ad.get("loop", true)),
		"frame_size": frame_size, "foot_anchor": foot_anchor,
		"kind": "", "frames": {}, "sheet": "", "columns": 0, "frame_count": 0, "rows": [], "dirs": [],
	}
	if ad.has("frame_size"):
		var fv: Variant = _vec2(ad["frame_size"])
		if fv == null or fv.x < 1 or fv.y < 1:
			_err("animation \"%s\": bad \"frame_size\"" % aid)
			return
		def["frame_size"] = Vector2i(fv)
	if ad.has("foot_anchor"):
		var av: Variant = _vec2(ad["foot_anchor"])
		if av == null:
			_err("animation \"%s\": bad \"foot_anchor\"" % aid)
			return
		def["foot_anchor"] = av
	var dirs: Array[String] = []
	if ad.has("frames") and typeof(ad["frames"]) == TYPE_DICTIONARY:
		def["kind"] = "frames"
		var fr: Dictionary = {}
		for k: Variant in ad["frames"]:
			var dn := norm_dir(k)
			var lst: Variant = ad["frames"][k]
			if dn.is_empty():
				_err("animation \"%s\": unknown direction \"%s\"" % [aid, str(k)])
				continue
			if typeof(lst) != TYPE_ARRAY or (lst as Array).is_empty():
				_err("animation \"%s\" direction %s: needs a non-empty list of PNG paths" % [aid, dn])
				continue
			var paths: Array[String] = []
			for p: Variant in lst:
				var full := base_dir.path_join(String(p))
				if check_files and not file_exists(full):
					_err("animation \"%s\" direction %s: missing file %s" % [aid, dn, full])
				paths.append(full)
			fr[dn] = paths
			dirs.append(dn)
		def["frames"] = fr
	elif ad.has("sheet"):
		def["kind"] = "sheet"
		var sheet := base_dir.path_join(String(ad["sheet"]))
		def["sheet"] = sheet
		var cols := int(ad.get("columns", 0))
		if cols < 1:
			_err("animation \"%s\": sheet needs \"columns\" >= 1" % aid)
			return
		def["columns"] = cols
		var fc := int(ad.get("frame_count", cols))
		def["frame_count"] = clampi(fc, 1, cols)
		if typeof(ad.get("rows")) != TYPE_ARRAY or (ad["rows"] as Array).is_empty():
			_err("animation \"%s\": sheet needs \"rows\" (one direction name per row)" % aid)
			return
		var rows: Array[String] = []
		for r: Variant in ad["rows"]:
			var rn := norm_dir(r)
			if rn.is_empty():
				_err("animation \"%s\": unknown row direction \"%s\"" % [aid, str(r)])
				return
			rows.append(rn)
			if not dirs.has(rn):
				dirs.append(rn)
		def["rows"] = rows
		if check_files and not file_exists(sheet):
			_err("animation \"%s\": missing sheet %s" % [aid, sheet])
	else:
		_err("animation \"%s\" needs either \"frames\" or \"sheet\"" % aid)
		return
	if dirs.is_empty():
		_err("animation \"%s\" has no usable directions" % aid)
		return
	def["dirs"] = dirs
	animations[aid] = def
	anim_order.append(aid)


func _check_cardinals() -> void:
	for aid: String in anim_order:
		for c: String in ["N", "E", "S", "W"]:
			var avail: Array = animations[aid]["dirs"]
			if not avail.has(c) and _mirror_source(c, avail).is_empty():
				_err("animation \"%s\": cardinal direction %s missing (provide it or a \"mirror\" entry)" % [aid, c])


# ---------------------------------------------------------------- directions

static func norm_dir(v: Variant) -> String:
	var t := String(v).strip_edges().to_upper()
	return t if DIRS8.has(t) else ""


## Snap a screen-space vector (y down) to one of the 8 direction names. Zero -> "S".
static func dir_name(v: Vector2) -> String:
	if v.length_squared() < 0.0001:
		return "S"
	var idx := posmod(int(roundf(v.angle() / (PI / 4.0))), 8)
	return OCTANT_DIRS[idx]


func _mirror_source(dir: String, avail: Array) -> String:
	var src := String(mirror.get(dir, ""))
	return src if (not src.is_empty() and avail.has(src)) else ""


## Resolve what to show for (anim, dir). Rule: own frames -> `mirror` (flip) -> for a diagonal the
## adjacent cardinals (vertical first, own frames then mirror) -> nearest available heading.
## Returns {"dir": String, "flip": bool, "fallback": bool} or {} if the animation is unknown.
func resolve(anim_id: String, dir: String) -> Dictionary:
	if not animations.has(anim_id):
		return {}
	var avail: Array = animations[anim_id]["dirs"]
	if avail.has(dir):
		return {"dir": dir, "flip": false, "fallback": false}
	var m := _mirror_source(dir, avail)
	if not m.is_empty():
		return {"dir": m, "flip": true, "fallback": false}
	var adj: Array[String] = []
	if dir.length() == 2:
		adj = [dir.substr(0, 1), dir.substr(1, 1)]
	for c: String in adj:
		if avail.has(c):
			return {"dir": c, "flip": false, "fallback": true}
		var mc := _mirror_source(c, avail)
		if not mc.is_empty():
			return {"dir": mc, "flip": true, "fallback": true}
	var want := DIRS8.find(dir)
	var best := ""
	var best_d := 99
	for cand: String in DIRS8:
		if avail.has(cand):
			var dd := absi(DIRS8.find(cand) - want)
			dd = mini(dd, 8 - dd)
			if dd < best_d:
				best_d = dd
				best = cand
	return {"dir": best, "flip": false, "fallback": true} if not best.is_empty() else {}


# ---------------------------------------------------------------- lazy build

## Top-left of a sheet cell in pixels (AtlasTexture region).
static func sheet_region(col: int, row: int, cell: Vector2i) -> Rect2i:
	return Rect2i(col * cell.x, row * cell.y, cell.x, cell.y)


func anim_anchor(anim_id: String) -> Vector2:
	return animations[anim_id]["foot_anchor"] if animations.has(anim_id) else foot_anchor


func anim_frame_size(anim_id: String) -> Vector2i:
	return animations[anim_id]["frame_size"] if animations.has(anim_id) else frame_size


static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".import")


## Imported texture when an import exists (exported builds), else decode the PNG directly.
static func load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path + ".import"):
		var t: Resource = load(path)
		return t as Texture2D
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func has_frames(anim_id: String) -> bool:
	return _cache.has(anim_id)


## Lazily build (and cache) a SpriteFrames for one animation: one SpriteFrames animation per
## direction, named by the direction. Returns null (and records an error) if it cannot be built.
func get_frames(anim_id: String) -> SpriteFrames:
	if _cache.has(anim_id):
		return _cache[anim_id]
	if not animations.has(anim_id):
		return null
	var t0 := Time.get_ticks_usec()
	var def: Dictionary = animations[anim_id]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var cell: Vector2i = def["frame_size"]
	var n := 0
	var ok := true
	if def["kind"] == "frames":
		for dn: String in def["frames"]:
			sf.add_animation(dn)
			sf.set_animation_speed(dn, def["fps"])
			sf.set_animation_loop(dn, def["loop"])
			for p: String in def["frames"][dn]:
				var tex := load_texture(p)
				if tex == null:
					_load_err("animation \"%s\": cannot load %s" % [anim_id, p])
					ok = false
					continue
				if Vector2i(tex.get_size()) != cell:
					_load_err("animation \"%s\": %s is %dx%d, expected %dx%d" % [anim_id, p, tex.get_width(), tex.get_height(), cell.x, cell.y])
				sf.add_frame(dn, tex)
				n += 1
	else:
		var sheet := load_texture(def["sheet"])
		if sheet == null:
			_load_err("animation \"%s\": cannot load sheet %s" % [anim_id, def["sheet"]])
			ok = false
		else:
			var rows: Array = def["rows"]
			var need := Vector2i(def["columns"] * cell.x, rows.size() * cell.y)
			if Vector2i(sheet.get_size()) != need:
				_load_err("animation \"%s\": sheet is %dx%d, expected %dx%d (columns x rows x frame_size)" % [anim_id, sheet.get_width(), sheet.get_height(), need.x, need.y])
			for r in rows.size():
				var dn: String = rows[r]
				if sf.has_animation(dn):
					continue  # first row wins for a repeated direction
				sf.add_animation(dn)
				sf.set_animation_speed(dn, def["fps"])
				sf.set_animation_loop(dn, def["loop"])
				for c in int(def["frame_count"]):
					var at := AtlasTexture.new()
					at.atlas = sheet
					at.region = Rect2(sheet_region(c, r, cell))
					sf.add_frame(dn, at)
					n += 1
	load_ms += (Time.get_ticks_usec() - t0) / 1000.0
	if not ok or n == 0:
		return null
	_cache[anim_id] = sf
	anims_loaded += 1
	frames_loaded += n
	return sf


# ---------------------------------------------------------------- helpers

static func _vec2(v: Variant) -> Variant:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:
		var a: Array = v
		if (typeof(a[0]) == TYPE_FLOAT or typeof(a[0]) == TYPE_INT) and (typeof(a[1]) == TYPE_FLOAT or typeof(a[1]) == TYPE_INT):
			return Vector2(float(a[0]), float(a[1]))
	return null
