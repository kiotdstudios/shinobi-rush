extends RefCounted
## Camera preset (CameraPreset module, ?camera= parsing, player camera, lab switch). Called from tests/run_tests.gd.
## (a) the pure functions: table, default, computed close zoom incl. the snap boundaries, query parsing, metrics,
## (b) scene level: the default is wide, the player's camera follows the ACTIVE preset and the figure height,
##     the lab list/labels/restore-on-close follow the preset, the lab key switches presets at runtime.
## Every scene test restores the active preset (a static slot) and the sprite library.

const TMP := "user://shinobi_tests_camera"
const VIEWPORT_H := 720.0

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_table_and_default()
	test_close_zoom()
	test_zoom_for()
	test_parse_query()
	test_metrics_and_labels()
	test_lab_zoom_list()
	await test_scene(tree_root)


func _near(a: float, b: float, eps: float = 1e-4) -> bool:
	return absf(a - b) < eps


# ------------------------------------------------------------------ (a) pure functions
func test_table_and_default() -> void:
	ck.call("camera preset: DEFAULT_ID is wide", CameraPreset.DEFAULT_ID == "wide" and CameraPreset.WIDE == "wide")
	ck.call("camera preset: the table has exactly wide and close, in that order", CameraPreset.IDS == ["wide", "close"] and CameraPreset.TABLE.has("wide") and CameraPreset.TABLE.has("close"))
	ck.call("camera preset: wide is 0.7500", _near(CameraPreset.zoom_for("wide"), 0.75, 1e-9) and _near(float(CameraPreset.TABLE["wide"]["zoom"]), 0.75, 1e-9))
	ck.call("camera preset: the default id resolves to the wide zoom", CameraPreset.zoom_for(CameraPreset.DEFAULT_ID) == CameraPreset.zoom_for("wide"))
	ck.call("camera preset: provisional tunables (fraction 0.175, band 16-19 %, range 0.25-4)", CameraPreset.CLOSE_FIGURE_FRACTION == 0.175 and CameraPreset.BAND_MIN_FRACTION == 0.16 and CameraPreset.BAND_MAX_FRACTION == 0.19 and CameraPreset.MIN_ZOOM == 0.25 and CameraPreset.MAX_ZOOM == 4.0)
	ck.call("camera preset: base viewport height comes from the project (720)", CameraPreset.base_viewport_height() == VIEWPORT_H)
	ck.call("camera preset: nothing chosen yet means the default", CameraPreset.active() == "wide" and CameraPreset.active_id() == "wide")


func test_close_zoom() -> void:
	# The 108 px placeholder: 0.175 * 720 / 108 = 1.1667 -> 126 px = 17.5 % (1.0 would give 15 %, outside the band).
	var z108 := CameraPreset.close_zoom(108.0)
	ck.call("close zoom: 108 px placeholder gives 1.1667", _near(z108, 1.0 + 1.0 / 6.0), str(z108))
	ck.call("close zoom: 108 px placeholder is 126 px on screen = 17.5 % of 720", _near(108.0 * z108, 126.0) and _near(CameraPreset.figure_fraction(108.0, z108), 0.175))
	ck.call("close zoom: 108 px at zoom 1.0 would be 15 %, outside the band (so no snap)", not CameraPreset.in_band(CameraPreset.figure_fraction(108.0, 1.0)))
	# Snap boundaries: 1.0 keeps the figure inside 16-19 % when the figure is 115.2..136.8 px.
	ck.call("close zoom: 115.2 px (exactly 16 %) snaps to 1.0", CameraPreset.close_zoom(115.2) == 1.0)
	ck.call("close zoom: 115.0 px (just outside 16 %) is computed, not snapped", _near(CameraPreset.close_zoom(115.0), 0.175 * 720.0 / 115.0) and CameraPreset.close_zoom(115.0) != 1.0)
	ck.call("close zoom: 116 px snaps to 1.0", CameraPreset.close_zoom(116.0) == 1.0)
	ck.call("close zoom: 128 px (the frame size, 17.8 %) snaps to 1.0", CameraPreset.close_zoom(128.0) == 1.0)
	ck.call("close zoom: 136.8 px (exactly 19 %) snaps to 1.0", CameraPreset.close_zoom(136.8) == 1.0)
	ck.call("close zoom: 137 px (just outside 19 %) is computed (0.9198)", _near(CameraPreset.close_zoom(137.0), 0.175 * 720.0 / 137.0) and CameraPreset.close_zoom(137.0) < 1.0)
	# Property: for every figure height either 1.0 is in the band, or the result puts the figure at 17.5 % (unless clamped).
	var prop_ok := true
	var bad := ""
	for h in range(30, 400):
		var fig := float(h)
		var z := CameraPreset.close_zoom(fig)
		var snapped_ok := z == 1.0 and CameraPreset.in_band(fig / VIEWPORT_H)
		var wanted := clampf(0.175 * VIEWPORT_H / fig, 0.25, 4.0)  # 17.5 % of the viewport, unless clamped
		var computed_ok := not CameraPreset.in_band(fig / VIEWPORT_H) and _near(z, wanted, 1e-6) and (z == 4.0 or z == 0.25 or _near(fig * z / VIEWPORT_H, 0.175, 1e-6))
		if not (snapped_ok or computed_ok):
			prop_ok = false
			bad = "fig=%d zoom=%s" % [h, z]
			break
	ck.call("close zoom: every figure 30..399 px is either snapped inside the band or lands on 17.5 %", prop_ok, bad)
	ck.call("close zoom: clamped to 4.0 for a tiny figure and 0.25 for a huge one", CameraPreset.close_zoom(24.0) == 4.0 and CameraPreset.close_zoom(1000.0) == 0.25)
	ck.call("close zoom: a zero or negative figure height falls back to the 108 px placeholder", _near(CameraPreset.close_zoom(0.0), z108) and _near(CameraPreset.close_zoom(-5.0), z108))
	ck.call("close zoom: scales with the viewport height (1080: 108 px gives 1.75, 180 px snaps)", _near(CameraPreset.close_zoom(108.0, 1080.0), 1.75) and CameraPreset.close_zoom(180.0, 1080.0) == 1.0)
	ck.call("close zoom: figure_height_px uses the placeholder 108 without a sprite set", CameraPreset.figure_height_px(null) == WorldScale.BODY_HEIGHT)
	var inline := SpriteSet.parse(JSON.stringify({"schema": 1, "frame_size": [32, 32], "body_height_px": 120, "animations": {"idle": {"fps": 12, "frames": {"S": ["a.png"], "E": ["a.png"], "N": ["a.png"], "W": ["a.png"]}}}}), "user://x/y.manifest.json", false)
	ck.call("close zoom: figure_height_px takes body_height_px from a valid sprite set", inline.is_valid() and CameraPreset.figure_height_px(inline) == 120.0)


func test_zoom_for() -> void:
	ck.call("zoom_for: names are case/space tolerant", _near(CameraPreset.zoom_for("CLOSE"), 1.1667) and _near(CameraPreset.zoom_for(" close "), 1.1667) and _near(CameraPreset.zoom_for(&"close"), 1.1667))
	ck.call("zoom_for: close follows the figure height (120 px snaps to 1.0, 60 px gives 2.1)", CameraPreset.zoom_for("close", 120.0) == 1.0 and _near(CameraPreset.zoom_for("close", 60.0), 2.1))
	ck.call("zoom_for: wide ignores the figure height", CameraPreset.zoom_for("wide", 60.0) == CameraPreset.zoom_for("wide", 300.0))
	ck.call("zoom_for: numbers pass through (2 -> 2.0, 0.5 -> 0.5, int 3 -> 3.0)", CameraPreset.zoom_for(2.0) == 2.0 and CameraPreset.zoom_for(0.5) == 0.5 and CameraPreset.zoom_for(3) == 3.0)
	ck.call("zoom_for: numbers are clamped to 0.25..4", CameraPreset.zoom_for(0.01) == 0.25 and CameraPreset.zoom_for(99.0) == 4.0)
	var wide := CameraPreset.zoom_for("wide")
	ck.call("zoom_for: unknown names, non-positive and non-finite numbers, wrong types fall back to wide", CameraPreset.zoom_for("zzz") == wide and CameraPreset.zoom_for("") == wide and CameraPreset.zoom_for(0.0) == wide and CameraPreset.zoom_for(-1.0) == wide and CameraPreset.zoom_for(NAN) == wide and CameraPreset.zoom_for(INF) == wide and CameraPreset.zoom_for(null) == wide and CameraPreset.zoom_for(Vector2.ONE) == wide)
	ck.call("id_of / next_id: wide, close, custom; next goes wide -> close -> wide, a number continues with wide", CameraPreset.id_of("wide") == "wide" and CameraPreset.id_of("close") == "close" and CameraPreset.id_of(2.0) == "custom" and CameraPreset.id_of("zzz") == "wide" and CameraPreset.next_id("wide") == "close" and CameraPreset.next_id("close") == "wide" and CameraPreset.next_id(2.0) == "wide")


func test_parse_query() -> void:
	var wide := CameraPreset.DEFAULT_ID
	ck.call("parse_query: empty, no camera key, bare '?' -> wide", CameraPreset.parse_query("") == wide and CameraPreset.parse_query("?") == wide and CameraPreset.parse_query("?debug=1") == wide and CameraPreset.parse_query("?cameras=close") == wide and CameraPreset.parse_query("?xcamera=close") == wide)
	ck.call("parse_query: valid names, with and without '?', any case", CameraPreset.parse_query("?camera=wide") == "wide" and CameraPreset.parse_query("camera=close") == "close" and CameraPreset.parse_query("?camera=CLOSE") == "close" and CameraPreset.parse_query("?camera=Wide") == "wide")
	ck.call("parse_query: found among other parameters", CameraPreset.parse_query("?debug=1&camera=close&testhooks=1") == "close")
	ck.call("parse_query: percent-encoded value and key are decoded", CameraPreset.parse_query("?camera=%63lose") == "close" and CameraPreset.parse_query("?%63amera=close") == "close")
	var two = CameraPreset.parse_query("?camera=2")
	var half = CameraPreset.parse_query("?camera=0.5")
	var one_five = CameraPreset.parse_query("?camera=1.5")
	ck.call("parse_query: numbers become floats (2, 0.5, 1.5)", typeof(two) == TYPE_FLOAT and two == 2.0 and typeof(half) == TYPE_FLOAT and half == 0.5 and one_five == 1.5)
	ck.call("parse_query: numbers are clamped to 0.25..4", CameraPreset.parse_query("?camera=0.01") == 0.25 and CameraPreset.parse_query("?camera=99") == 4.0 and CameraPreset.parse_query("?camera=4") == 4.0 and CameraPreset.parse_query("?camera=0.25") == 0.25)
	ck.call("parse_query: zero and negative numbers are garbage -> wide", CameraPreset.parse_query("?camera=0") == wide and CameraPreset.parse_query("?camera=-2") == wide and CameraPreset.parse_query("?camera=0.0") == wide)
	var garbage_ok := true
	var bad := ""
	for g: String in ["abc", "", "closee", "clos", "wide close", "2x", "x2", "1,5", "nan", "inf", "-inf", "1e999", "1e2", "0x10", "close;wide", "<script>", "../../x", "null", "undefined", "true", "%", "%zz", "wide%00", "999999999999999999999999"]:
		var r = CameraPreset.parse_query("?camera=" + g)
		# '999...' is a number: clamped to 4, not garbage. Everything else must fall back to wide.
		var expect: Variant = 4.0 if g == "999999999999999999999999" else wide
		if r != expect or typeof(r) != typeof(expect):
			garbage_ok = false
			bad = "'%s' -> %s" % [g, str(r)]
			break
	ck.call("parse_query: garbage values fall back to wide (and huge numbers clamp)", garbage_ok, bad)
	ck.call("parse_query: key without a value or without '=' -> wide", CameraPreset.parse_query("?camera") == wide and CameraPreset.parse_query("?camera=") == wide and CameraPreset.parse_query("?camera&debug=1") == wide)
	ck.call("parse_query: repeated key: the first one wins (like URLSearchParams.get)", CameraPreset.parse_query("?camera=close&camera=wide") == "close" and CameraPreset.parse_query("?camera=wide&camera=close") == "wide" and CameraPreset.parse_query("?camera=zzz&camera=close") == wide)
	ck.call("parse_query: empty segments and stray '&' are skipped", CameraPreset.parse_query("?&&camera=close&&") == "close")


func test_metrics_and_labels() -> void:
	var z := CameraPreset.zoom_for("close")
	var m := CameraPreset.metrics(z, WorldScale.BODY_HEIGHT)
	ck.call("metrics: close/108 px is 126 px, 17.5 %, in band, view 1097x617", _near(m["figure_screen_px"], 126.0) and _near(m["fraction"], 0.175) and m["in_band"] == true and _near(m["view_w"], 1280.0 / z, 0.01) and _near(m["view_h"], 617.14, 0.01), str(m))
	var w := CameraPreset.metrics(CameraPreset.zoom_for("wide"), WorldScale.BODY_HEIGHT)
	ck.call("metrics: wide/108 px is 81 px, 11.25 %, outside the band, view 1706.7x960", _near(w["figure_screen_px"], 81.0) and _near(w["fraction"], 81.0 / 720.0) and w["in_band"] == false and _near(w["view_w"], 1280.0 / 0.75, 0.01) and _near(w["view_h"], 960.0, 0.01), str(w))
	var r := CameraPreset.visible_world_rect(CameraPreset.zoom_for("wide"), Vector2(0, 135))
	ck.call("visible_world_rect: wide centred on the spawn is 1706.7x960", r.is_equal_approx(Rect2(-1280.0 / 1.5, 135.0 - 480.0, 1280.0 / 0.75, 960.0)), str(r))
	ck.call("label_for: 'wide 0.75x', 'close 1.17x', 'custom 2.00x'", CameraPreset.label_for("wide", CameraPreset.zoom_for("wide")) == "wide 0.75x" and CameraPreset.label_for("close", z) == "close 1.17x" and CameraPreset.label_for(2.0, 2.0) == "custom 2.00x")
	var src := FileAccess.get_file_as_string("res://scripts/web/web_bridge.gd")
	ck.call("state: WebBridge publishes camera_preset next to the existing fields", src.contains("_state.camera_preset = ") and src.contains("_state.zoom = ") and src.contains("_state.view_w = "))
	var bridge := load("res://scripts/web/web_bridge.gd")
	bridge.apply_camera_query("?camera=close")
	var chose_close := CameraPreset.active_id() == "close"
	bridge.apply_camera_query("?camera=2")
	var chose_custom: bool = CameraPreset.active_id() == "custom" and float(CameraPreset.active()) == 2.0
	bridge.apply_camera_query("?camera=garbage")
	var back_to_wide := CameraPreset.active_id() == "wide"
	bridge.apply_camera_query("")
	ck.call("WebBridge.apply_camera_query: close, custom number, garbage -> wide, empty -> wide", chose_close and chose_custom and back_to_wide and CameraPreset.active_id() == "wide")
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)


## The animation lab's zoom list and labels (pure statics): [baseline, 1, 1.5, 2, 2.5, 3, 3.5, 4].
func test_lab_zoom_list() -> void:
	var wide := CameraPreset.zoom_for("wide")
	var steps: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0]
	var zl := AnimationLab.zoom_list(wide)
	ck.call("lab zoom list: [wide, 1, 1.25, 1.5, ..., 4]; the first step after the baseline is exactly 1.0, the cap is 4", zl.size() == 14 and zl[0] == wide and zl[1] == 1.0 and str(zl.slice(1)) == str(steps) and zl.max() == CameraPreset.MAX_ZOOM, str(zl))
	var names: Array[String] = []
	for i in zl.size():
		names.append(AnimationLab.zoom_label(i, wide, "wide"))
	ck.call("lab zoom labels: 'wide 0.75x' then 1x 1.25x 1.5x 1.75x 2x 2.25x 2.5x 2.75x 3x 3.25x 3.5x 3.75x 4x", str(names) == str(["wide 0.75x", "1x", "1.25x", "1.5x", "1.75x", "2x", "2.25x", "2.5x", "2.75x", "3x", "3.25x", "3.5x", "3.75x", "4x"]), str(names))
	ck.call("lab zoom labels: the close baseline reads 'close 1.21x' (104 px art) and an index past the end clamps to 4x", AnimationLab.zoom_label(0, CameraPreset.close_zoom(104.0), "close") == "close 1.21x" and AnimationLab.zoom_label(99, wide) == "4x")
	# a baseline equal to ANY step (whole, half, or quarter -- exactly or within float noise) is listed once, in front; the other steps stay
	var dedupe_bad := ""
	for s: float in steps:
		for b: float in [s, s + 1e-7, s - 1e-7]:
			var l := AnimationLab.zoom_list(b)
			var same := 0
			for e: float in l:
				if is_equal_approx(e, s):
					same += 1
			if dedupe_bad == "" and (l.size() != steps.size() or l[0] != b or same != 1):
				dedupe_bad = "baseline %s -> %s" % [b, str(l)]
	ck.call("lab zoom list: a baseline equal to any step (1, 1.25, ..., 3.75, 4) is not listed twice", dedupe_bad == "", dedupe_bad)
	var keep_ok := true
	for b: float in [0.25, 0.6, 0.8, 1.1, CameraPreset.close_zoom(108.0), wide]:
		keep_ok = keep_ok and AnimationLab.zoom_list(b).size() == steps.size() + 1
	ck.call("lab zoom list: a baseline that is not a step (0.25, 0.6, 0.8, 1.1, close 1.17, wide 0.5) keeps all thirteen steps", keep_ok)
	var half_labels: Array[String] = []
	for i in 3:
		half_labels.append(AnimationLab.zoom_label(i, 1.5, 1.5))
	ck.call("lab zoom labels: with a 1.5 baseline the list reads 'custom 1.50x', '1x', '1.25x'", str(half_labels) == str(["custom 1.50x", "1x", "1.25x"]), str(half_labels))


# ------------------------------------------------------------------ (b) scene level
func _png(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2, 1.0))
	img.save_png(path)


## A tiny valid set (idle only) with the given manifest body_height_px.
func _make_set(id: String, body_h: int) -> SpriteSet:
	var base := TMP.path_join(id)
	var five := ["S", "E", "N", "SE", "NE"]
	var frames := {}
	for d: String in five:
		frames[d] = ["idle/%s_0.png" % d]
		_png(base.path_join("idle/%s_0.png" % d))
	var m := {
		"schema": 1, "id": id, "frame_size": [32, 32], "foot_anchor": [16, 28], "body_height_px": body_h,
		"directions": five, "mirror": {"W": "E", "SW": "SE", "NW": "NE"},
		"animations": {"idle": {"fps": 12, "loop": true, "frames": frames}},
	}
	var path := base.path_join(id + ".manifest.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	return SpriteSet.parse(FileAccess.get_file_as_string(path), path)


func _rm(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var n := da.get_next()
	while n != "":
		if da.current_is_dir():
			_rm(dir.path_join(n))
		else:
			da.remove(n)
		n = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(dir)


func _press(node: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	node._unhandled_input(ev)


func _boot(tree_root: Node, spec: Variant, sets: Array) -> Node:
	var lib := SpriteLibrary.get_instance()
	lib.sets.clear()
	for s in sets:
		lib.sets.append(s)
	CameraPreset.set_active(spec)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await tree_root.get_tree().process_frame
	return main


func test_scene(tree_root: Node) -> void:
	var lib := SpriteLibrary.get_instance()
	var saved: Array[SpriteSet] = lib.sets.duplicate()
	var set108 := _make_set("t_cp_108", 108)
	var set120 := _make_set("t_cp_120", 120)
	var vp: Vector2 = tree_root.get_viewport().get_visible_rect().size
	var wide := CameraPreset.zoom_for("wide")
	var close108 := 0.175 * 720.0 / 108.0

	# ---- default: no parameter / nothing chosen -> wide, exactly today's numbers
	var main := await _boot(tree_root, CameraPreset.DEFAULT_ID, [set108])
	var lab := main.get_node("AnimationLab") as AnimationLab
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var cam := player.camera
	ck.call("camera scene: default preset is wide and the camera zoom equals the wide preset (0.7500)", CameraPreset.active_id() == "wide" and absf(cam.zoom.x - wide) < 1e-6 and absf(cam.zoom.x - CameraPreset.zoom_for(CameraPreset.active(), player.figure_height_px())) < 1e-6 and absf(player.camera_baseline - wide) < 1e-9, "zoom=%s id=%s" % [cam.zoom, CameraPreset.active_id()])
	ck.call("camera scene: default view is 1706.7x960", (vp / cam.zoom.x).is_equal_approx(Vector2(1280.0 / 0.75, 960)), str(vp / cam.zoom.x))
	var zoom_label := lab._value_labels["zoom"] as Label
	var preset_label := lab._value_labels["preset"] as Label
	ck.call("camera scene: lab shows 'wide 0.75x' and the preset row says wide", zoom_label.text == "wide 0.75x" and preset_label.text == "wide", "%s / %s" % [zoom_label.text, preset_label.text])
	# a wide camera does not care about the figure height (set120 would change a close zoom)
	lab._select_set(-1)
	ck.call("camera scene: wide does not move when the figure height changes", absf(cam.zoom.x - wide) < 1e-6)
	main.queue_free()
	await tree_root.get_tree().process_frame

	# ---- close: computed from the figure height of the active visual (108 px set -> 1.1667)
	main = await _boot(tree_root, "close", [set108, set120])
	lab = main.get_node("AnimationLab") as AnimationLab
	_press(lab, "dbg_toggle_lab")  # Lab now starts closed even with loaded art.
	player = main.get_node("TrainingArena/Player") as PlayerController
	cam = player.camera
	zoom_label = lab._value_labels["zoom"] as Label
	preset_label = lab._value_labels["preset"] as Label
	ck.call("camera scene: close preset gives zoom 1.1667 for a 108 px set", player.figure_height_px() == 108.0 and absf(cam.zoom.x - close108) < 1e-6 and absf(player.camera_baseline - close108) < 1e-9, "zoom=%s fig=%s" % [cam.zoom, player.figure_height_px()])
	var view: Vector2 = vp / cam.zoom.x
	ck.call("camera scene: close view is 1097x617 and the figure is 126 px (17.5 %) of 720", absf(view.x - 1097.14) < 0.01 and absf(view.y - 617.14) < 0.01 and absf(player.figure_height_px() * cam.zoom.x - 126.0) < 1e-3, str(view))
	ck.call("camera scene: close keeps the head/foot room and limits (limited area >= view, no void)", (cam.limit_right - cam.limit_left) >= view.x and (cam.limit_bottom - cam.limit_top) >= view.y and cam.limit_top == int(WorldScale.ARENA_BOUNDS.position.y - WorldScale.CAMERA_HEADROOM) and cam.limit_bottom == int(WorldScale.ARENA_BOUNDS.end.y + WorldScale.CAMERA_FOOTROOM))
	ck.call("camera scene: lab list is [close baseline, 1, 1.25, ..., 4] and the label says 'close 1.17x'", AnimationLab.zoom_list(player.camera_baseline).size() == 14 and zoom_label.text == "close 1.17x" and preset_label.text == "close", "%s / %s" % [zoom_label.text, preset_label.text])
	var seen: Array[float] = []
	var labels: Array[String] = []
	for i in 14:
		_press(lab, "dbg_zoom_cycle")
		seen.append(cam.zoom.x)
		labels.append(zoom_label.text)
	ck.call("camera scene: Z walks 1,1.25,1.5,...,4 and back to the close baseline", seen.size() == 14 and seen[0] == 1.0 and str(seen.slice(0, 13)) == str([1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0]) and absf(seen[13] - close108) < 1e-6 and str(labels) == str(["1x", "1.25x", "1.5x", "1.75x", "2x", "2.25x", "2.5x", "2.75x", "3x", "3.25x", "3.5x", "3.75x", "4x", "close 1.17x"]), str(seen) + str(labels))
	for i in 5:
		_press(lab, "dbg_zoom_cycle")  # 1x, 1.25x, 1.5x, 1.75x, 2x
	ck.call("camera scene: lab at 2x", cam.zoom.x == 2.0 and lab.zoom_index == 5)
	_press(lab, "dbg_toggle_lab")  # close the lab
	ck.call("camera scene: closing the lab restores the ACTIVE (close) baseline", not lab.lab_on and lab.zoom_index == 0 and absf(cam.zoom.x - close108) < 1e-6, str(cam.zoom))
	_press(lab, "dbg_toggle_lab")  # re-open
	ck.call("camera scene: opening the lab keeps the close baseline", lab.lab_on and absf(cam.zoom.x - close108) < 1e-6)
	# ---- the close zoom follows the figure height when the sprite set changes (no restart)
	lab._select_set(1)  # 120 px set: 1.0 is inside 16-19 %, so the zoom snaps to pixel-exact 1.0
	ck.call("camera follow: switching to a 120 px set snaps the close zoom to exactly 1.0", player.figure_height_px() == 120.0 and cam.zoom.x == 1.0 and player.camera_baseline == 1.0, "zoom=%s" % cam.zoom)
	ck.call("camera follow: the lab list drops the duplicate 1.0 (13 entries) and labels 'close 1.00x'", AnimationLab.zoom_list(player.camera_baseline).size() == 13 and zoom_label.text == "close 1.00x" and lab.zoom_index == 0, zoom_label.text)
	var seen2: Array[float] = []
	for i in 13:
		_press(lab, "dbg_zoom_cycle")
		seen2.append(cam.zoom.x)
	ck.call("camera follow: Z walks 1.25,1.5,...,4 and back to the snapped baseline 1.0", str(seen2) == str([1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 1.0]), str(seen2))
	for i in 4:
		_press(lab, "dbg_zoom_cycle")  # 1.25x, 1.5x, 1.75x, 2x
	lab._select_set(0)  # back to the 108 px set while the lab is at 2x: the camera stays at 2x, the baseline moves
	ck.call("camera follow: a set change at 2x does not overwrite the lab zoom, but the baseline moves", cam.zoom.x == 2.0 and absf(player.camera_baseline - close108) < 1e-6 and zoom_label.text == "2x" and lab.zoom_index == 5, "zoom=%s base=%s label=%s idx=%d" % [cam.zoom, player.camera_baseline, zoom_label.text, lab.zoom_index])
	for i in 6:
		_press(lab, "dbg_zoom_cycle")  # 2.25x, 2.5x, 2.75x, 3x, 3.25x, 3.5x
	lab._select_set(1)  # 120 px set again: the baseline snaps to 1.0 while the lab sits on the 3.5x step
	ck.call("camera follow: a baseline change at the 3.5x step keeps it, and the index follows the new list", cam.zoom.x == 3.5 and player.camera_baseline == 1.0 and zoom_label.text == "3.5x" and lab.zoom_index == 10, "zoom=%s base=%s label=%s idx=%d" % [cam.zoom, player.camera_baseline, zoom_label.text, lab.zoom_index])
	lab._select_set(0)  # and back to the 108 px set
	ck.call("camera follow: ...and back again it is still 3.5x at index 11 of the 14-entry list", cam.zoom.x == 3.5 and absf(player.camera_baseline - close108) < 1e-6 and zoom_label.text == "3.5x" and lab.zoom_index == 11, "zoom=%s label=%s idx=%d" % [cam.zoom, zoom_label.text, lab.zoom_index])
	_press(lab, "dbg_toggle_lab")
	ck.call("camera follow: closing the lab then restores the NEW baseline", absf(cam.zoom.x - close108) < 1e-6 and lab.zoom_index == 0)
	_press(lab, "dbg_toggle_lab")
	lab._select_set(-1)  # placeholder: 108 px
	ck.call("camera follow: the placeholder figure is 108 px, close zoom 1.1667 again", player.figure_height_px() == 108.0 and absf(cam.zoom.x - close108) < 1e-6)

	# ---- runtime switch with the lab key (action dbg_camera_preset, key N)
	ck.call("lab key: the preset action exists with the N key", InputMap.has_action(AnimationLab.PRESET_ACTION) and AnimationLab.PRESET_KEY == KEY_N)
	_press(lab, AnimationLab.PRESET_ACTION)
	ck.call("lab key: N switches close -> wide (zoom, id, labels)", CameraPreset.active_id() == "wide" and absf(cam.zoom.x - wide) < 1e-6 and zoom_label.text == "wide 0.75x" and preset_label.text == "wide", "%s %s %s" % [CameraPreset.active_id(), cam.zoom, zoom_label.text])
	_press(lab, AnimationLab.PRESET_ACTION)
	ck.call("lab key: N switches wide -> close again", CameraPreset.active_id() == "close" and absf(cam.zoom.x - close108) < 1e-6 and zoom_label.text == "close 1.17x")
	_press(lab, "dbg_zoom_cycle")
	_press(lab, "dbg_zoom_cycle")  # 1x, 1.5x (a half step)
	_press(lab, AnimationLab.PRESET_ACTION)
	ck.call("lab key: N while zoomed goes to the new baseline (index 0)", lab.zoom_index == 0 and absf(cam.zoom.x - wide) < 1e-6 and CameraPreset.active_id() == "wide")
	# the panel row (buttons < >) does what the key does
	var prow: Node = lab._panel.get_child(0).get_children()[9]
	ck.call("lab button: the 'Cam preset' row (title, <, >, value) exists after the overlay grid and the preset is wide", prow.get_child_count() == 4 and CameraPreset.active_id() == "wide")
	(prow.get_child(2) as Button).pressed.emit()
	ck.call("lab button: '>' switches the preset like N (close, zoom 1.1667, row text)", CameraPreset.active_id() == "close" and absf(cam.zoom.x - close108) < 1e-6 and preset_label.text == "close")
	(prow.get_child(1) as Button).pressed.emit()
	ck.call("lab button: '<' switches it back (wide)", CameraPreset.active_id() == "wide" and absf(cam.zoom.x - wide) < 1e-6)
	main.queue_free()
	await tree_root.get_tree().process_frame

	# ---- a plain number (?camera=2)
	main = await _boot(tree_root, 2.0, [set108])
	lab = main.get_node("AnimationLab") as AnimationLab
	_press(lab, "dbg_toggle_lab")  # Lab now starts closed even with loaded art.
	player = main.get_node("TrainingArena/Player") as PlayerController
	ck.call("camera scene: a numeric preset (2) sets zoom 2.0, id 'custom', label 'custom 2.00x'", player.camera.zoom.x == 2.0 and CameraPreset.active_id() == "custom" and (lab._value_labels["zoom"] as Label).text == "custom 2.00x" and (lab._value_labels["preset"] as Label).text == "custom", "%s %s" % [player.camera.zoom, (lab._value_labels["zoom"] as Label).text])
	_press(lab, AnimationLab.PRESET_ACTION)
	ck.call("lab key: N from a numeric preset continues with wide", CameraPreset.active_id() == "wide" and absf(player.camera.zoom.x - wide) < 1e-6)
	main.queue_free()
	await tree_root.get_tree().process_frame

	# ---- a plain number that is also a lab half step (?camera=1.5): the lab list shows it once, in front
	main = await _boot(tree_root, 1.5, [set108])
	lab = main.get_node("AnimationLab") as AnimationLab
	_press(lab, "dbg_toggle_lab")  # Lab now starts closed even with loaded art.
	player = main.get_node("TrainingArena/Player") as PlayerController
	cam = player.camera
	zoom_label = lab._value_labels["zoom"] as Label
	ck.call("camera scene: ?camera=1.5 sets zoom 1.5 ('custom 1.50x') and the lab list shows 1.5 once, in front", cam.zoom.x == 1.5 and zoom_label.text == "custom 1.50x" and str(AnimationLab.zoom_list(player.camera_baseline)) == str([1.5, 1.0, 1.25, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0]), "%s %s %s" % [cam.zoom, zoom_label.text, AnimationLab.zoom_list(player.camera_baseline)])
	var seen3: Array[float] = []
	var labels3: Array[String] = []
	for i in 13:
		_press(lab, "dbg_zoom_cycle")
		seen3.append(cam.zoom.x)
		labels3.append(zoom_label.text)
	ck.call("camera scene: Z from a 1.5 baseline walks 1,1.25,1.75,...,4 and back to 1.5 (1.5 is never visited twice)", str(seen3) == str([1.0, 1.25, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 1.5]) and str(labels3) == str(["1x", "1.25x", "1.75x", "2x", "2.25x", "2.5x", "2.75x", "3x", "3.25x", "3.5x", "3.75x", "4x", "custom 1.50x"]), str(seen3) + str(labels3))
	_press(lab, "dbg_toggle_lab")  # close
	ck.call("camera scene: closing the lab restores the 1.5 baseline", not lab.lab_on and lab.zoom_index == 0 and cam.zoom.x == 1.5, str(cam.zoom))
	main.queue_free()
	await tree_root.get_tree().process_frame

	# ---- restore the shared state
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)
	lib.sets.clear()
	lib.sets.append_array(saved)
	_rm(TMP)
