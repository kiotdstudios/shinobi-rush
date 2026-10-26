extends SceneTree
## Dependency-free test runner (no GUT / gdUnit4).
## Run: godot --headless --path . --script res://tests/run_tests.gd
## One line per test, a summary, exit code 1 on any failure.
## Sprite fixtures are generated at test time under user://shinobi_tests/ and removed afterwards.

const TMP := "user://shinobi_tests"
const DIRS8 := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

var passed: int = 0
var failed: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, ((" :: " + extra) if extra != "" else ""))


func _initialize() -> void:
	_cleanup()
	test_input_map()
	test_export_preset()
	test_web_bridge_inert()
	test_direction_snapping()
	test_manifest_parser()
	test_resolve_mirror_fallback()
	test_sheet_slicing_and_lazy_cache()
	test_discovery()
	await test_anchor_stability()
	BlightwoodMap.enabled = false  # the starting map lays ~3000 tiles; its own test turns it on
	AncientShrineSection.enabled = false  # the shrine section adds ~40 objects to the default arena; layout tests assume the plain arena
	PlayerController.death_sequence_enabled = false  # most tests assume the instant respawn; test_damage_reactions enables it locally
	Bandit.substitution_enabled = false  # random log swaps would flake combat tests; test_bandit_sub_kunai enables it locally
	await test_main_scene_and_movement()
	await test_jump_and_dodge_chaining()
	await test_lab_and_pause()
	await test_camera_framing()
	await load("res://tests/test_camera_preset.gd").new().run(ck, root)
	await load("res://tests/test_camera_impact.gd").new().run(ck, root)
	await load("res://tests/test_arena_sorting.gd").new().run(ck, root)
	await load("res://tests/test_wall_art.gd").new().run(ck, root)
	await load("res://tests/test_combat.gd").new().run(ck, root)
	await load("res://tests/test_jump.gd").new().run(ck, root)
	await load("res://tests/test_health_flicker.gd").new().run(ck, root)
	await load("res://tests/test_body_flicker_premium.gd").new().run(ck, root)
	await load("res://tests/test_health_gourd.gd").new().run(ck, root)
	await load("res://tests/test_gourd_pickup_fx.gd").new().run(ck, root)
	await load("res://tests/test_inventory.gd").new().run(ck, root)
	await load("res://tests/test_kunai_recovery.gd").new().run(ck, root)
	await load("res://tests/test_paper_tag.gd").new().run(ck, root)
	await load("res://tests/test_tag_bomb_items.gd").new().run(ck, root)
	await load("res://tests/test_ancient_shrine.gd").new().run(ck, root)
	await load("res://tests/test_starting_area.gd").new().run(ck, root)
	await load("res://tests/test_blightwood_map.gd").new().run(ck, root)
	await load("res://tests/test_damage_reactions.gd").new().run(ck, root)
	await load("res://tests/test_builder_spawn.gd").new().run(ck, root)
	await load("res://tests/test_bridge.gd").new().run(ck, root)
	await load("res://tests/test_water_walk.gd").new().run(ck, root)
	await load("res://tests/test_chidori.gd").new().run(ck, root)
	await load("res://tests/test_builder_bandit.gd").new().run(ck, root)
	await load("res://tests/test_builder_pro.gd").new().run(ck, root)
	await load("res://tests/test_blightwood_rocks.gd").new().run(ck, root)
	await load("res://tests/test_fence_kit.gd").new().run(ck, root)
	await load("res://tests/test_paint_tool.gd").new().run(ck, root)
	await load("res://tests/test_substitution_throw.gd").new().run(ck, root)
	await load("res://tests/test_chakra_charge.gd").new().run(ck, root)
	await load("res://tests/test_settings_tabs.gd").new().run(ck, root)
	await load("res://tests/test_combat_b.gd").new().run(ck, root)
	await load("res://tests/test_builder_dims.gd").new().run(ck, root)
	await load("res://tests/test_bandit_art.gd").new().run(ck, root)
	await load("res://tests/test_bandit_chase.gd").new().run(ck, root)
	await load("res://tests/test_bandit_robber.gd").new().run(ck, root)
	await load("res://tests/test_bandit_sub_kunai.gd").new().run(ck, root)
	await load("res://tests/test_bandit_world.gd").new().run(ck, root)
	await load("res://tests/test_log_pips.gd").new().run(ck, root)
	await load("res://tests/test_wall_colliders.gd").new().run(ck, root)
	await load("res://tests/test_floor_replace.gd").new().run(ck, root)
	await load("res://tests/test_map_editor.gd").new().run(ck, root)
	await load("res://tests/test_tight_select.gd").new().run(ck, root)
	await load("res://tests/test_bandit_vision_overlay.gd").new().run(ck, root)
	await load("res://tests/test_sense_vision_overlay.gd").new().run(ck, root)
	await load("res://tests/test_kunai_primary_proof.gd").new().run(ck, root)
	await load("res://tests/test_player_flicker_proof.gd").new().run(ck, root)
	await load("res://tests/test_kunai_attack_wiring.gd").new().run(ck, root)
	await load("res://tests/test_kunai_eight.gd").new().run(ck, root)
	await load("res://tests/test_blossom_trees.gd").new().run(ck, root)
	await load("res://tests/test_fire_pillar.gd").new().run(ck, root)
	await load("res://tests/test_wind_grass.gd").new().run(ck, root)
	await load("res://tests/test_floor_coverage.gd").new().run(ck, root)
	await load("res://tests/test_proximity_sense.gd").new().run(ck, root)
	await load("res://tests/test_lock_on.gd").new().run(ck, root)
	await load("res://tests/test_world_editor.gd").new().run(ck, root)
	await load("res://tests/test_builder_ground.gd").new().run(ck, root)
	await load("res://tests/test_builder_ashen.gd").new().run(ck, root)
	await load("res://tests/test_builder_fire.gd").new().run(ck, root)
	await load("res://tests/test_builder_blightwood.gd").new().run(ck, root)
	await load("res://tests/test_builder_water.gd").new().run(ck, root)
	await load("res://tests/test_builder_shorelines.gd").new().run(ck, root)
	await load("res://tests/test_dynamic_shrine.gd").new().run(ck, root)
	await load("res://tests/test_shrine_elevation.gd").new().run(ck, root)
	await load("res://tests/test_cliff_elevation.gd").new().run(ck, root)
	await load("res://tests/test_damage_art.gd").new().run(ck, root)
	await load("res://tests/test_wall_kit_sort.gd").new().run(ck, root)
	await load("res://tests/test_publish_to_github.gd").new().run(ck, root)
	await load("res://tests/test_asset_store_plugins.gd").new().run(ck, root)
	var debug_store_tests = load("res://tests/test_debug_store.gd").new()
	debug_store_tests.run(ck)
	var browser_debug_tests = load("res://tests/test_browser_debug.gd").new()
	browser_debug_tests.run(ck, root)
	var debug_export_tests = load("res://tests/test_debug_export.gd").new()
	debug_export_tests.run(ck, root)
	var debug_telemetry_tests = load("res://tests/test_debug_telemetry.gd").new()
	debug_telemetry_tests.run(ck, root)
	_cleanup()
	print("SUMMARY: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ helpers
func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(text)
	f.close()


func _png(path: String, w: int, h: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2, 1.0))
	img.save_png(path)


func _cleanup() -> void:
	_rm(TMP)


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


## 32x32 cell set: idle = per-frame lists, run/sprint = sheets (3 columns, 5 rows). W/SW/NW by mirror.
func _make_set(id: String) -> SpriteSet:
	var base := TMP.path_join(id)
	var five := ["S", "E", "N", "SE", "NE"]
	var frames := {}
	for d: String in five:
		frames[d] = ["idle/%s_0.png" % d, "idle/%s_1.png" % d]
		_png(base.path_join("idle/%s_0.png" % d), 32, 32)
		_png(base.path_join("idle/%s_1.png" % d), 32, 32)
	_png(base.path_join("run.png"), 96, 160)
	_png(base.path_join("sprint.png"), 96, 160)
	var m := {
		"schema": 1, "id": id, "frame_size": [32, 32], "foot_anchor": [16, 28], "body_height_px": 24,
		"directions": five, "mirror": {"W": "E", "SW": "SE", "NW": "NE"}, "unknown_key": 123,
		"animations": {
			"idle": {"fps": 12, "loop": true, "frames": frames},
			"run": {"fps": 24, "loop": true, "sheet": "run.png", "columns": 3, "rows": five},
			"sprint": {"fps": 30, "loop": true, "sheet": "sprint.png", "columns": 3, "rows": five},
		},
	}
	var path := base.path_join(id + ".manifest.json")
	_write(path, JSON.stringify(m))
	return SpriteSet.parse(FileAccess.get_file_as_string(path), path)


func _parse_inline(d: Dictionary) -> SpriteSet:
	return SpriteSet.parse(JSON.stringify(d), TMP.path_join("inline/x.manifest.json"), false)


func _base_manifest() -> Dictionary:
	return {
		"schema": 1, "frame_size": [32, 32],
		"animations": {"idle": {"fps": 12, "frames": {"S": ["a.png"], "E": ["a.png"], "N": ["a.png"], "W": ["a.png"]}}},
	}


# ------------------------------------------------------------------ 3.6 tests
func test_input_map() -> void:
	var implemented := ["move_left", "move_right", "move_up", "move_down", "sprint", "pause", "slot_up", "slot_right", "slot_down", "slot_left", "player_menu"]
	var reserved := ["aim_left", "aim_right", "aim_up", "aim_down", "attack_light", "attack_heavy", "dodge", "jump", "heal", "substitution", "jutsu_modifier"]
	for a: String in implemented:
		var has_key := false
		var has_pad := false
		if InputMap.has_action(a):
			for e in InputMap.action_get_events(a):
				if e is InputEventKey:
					has_key = true
				elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
					has_pad = true
		ck("input: %s has keyboard + joypad events" % a, has_key and has_pad)
	for a: String in reserved:
		ck("input: reserved %s exists with an event" % a, InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0)
	for a: String in ["dbg_toggle_lab", "dbg_set_prev", "dbg_set_next", "dbg_anim_prev", "dbg_anim_next", "dbg_dir_prev", "dbg_dir_next", "dbg_compare", "dbg_zoom_cycle", "dbg_overlay_ruler"]:
		ck("input: %s exists" % a, InputMap.has_action(a))


func test_export_preset() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	ck("export_presets.cfg loads", err == OK)
	ck("export: thread_support is false", cfg.get_value("preset.0.options", "variant/thread_support", true) == false)
	ck("export: manifests ship (include_filter has *.json)", String(cfg.get_value("preset.0", "include_filter", "")).contains("*.json"))


func test_web_bridge_inert() -> void:
	var wb := root.get_node_or_null("WebBridge")
	ck("WebBridge autoload present", wb != null)
	if wb != null:
		ck("WebBridge inert outside Web (not active, not processing)", wb.active == false and not wb.is_processing())
	ck("not running as a Web feature", not OS.has_feature("web"))


# ------------------------------------------------------------------ 7.7 tests
func test_direction_snapping() -> void:
	var vecs := [Vector2.DOWN, Vector2(1, 1), Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1)]
	var got: Array[String] = []
	for v: Vector2 in vecs:
		got.append(SpriteSet.dir_name(v))
	ck("dir_name snaps all 8 headings", got == DIRS8, str(got))
	ck("dir_name snaps off-axis (0.3 rad) to E", SpriteSet.dir_name(Vector2.from_angle(0.3)) == "E")
	ck("dir_name zero vector -> S", SpriteSet.dir_name(Vector2.ZERO) == "S")
	var ok := true
	for i in 8:
		var s := PlayerController._snap8(vecs[i])
		if absf(s.length() - 1.0) > 0.02 or SpriteSet.dir_name(s) != DIRS8[i]:
			ok = false
	ck("PlayerController._snap8 gives (near) unit headings matching dir_name", ok)


func test_manifest_parser() -> void:
	var s := _make_set("t32")
	ck("parser: valid set has no errors (frames + sheet + mirror)", s.is_valid(), str(s.errors))
	ck("parser: id / frame_size / anchor / body height", s.id == "t32" and s.frame_size == Vector2i(32, 32) and s.foot_anchor == Vector2(16, 28) and s.body_height_px == 24.0)
	ck("parser: animation order kept", s.anim_order == ["idle", "run", "sprint"], str(s.anim_order))
	ck("parser: frames form", s.animations["idle"]["kind"] == "frames" and s.animations["idle"]["frames"]["S"].size() == 2)
	ck("parser: sheet form", s.animations["run"]["kind"] == "sheet" and s.animations["run"]["columns"] == 3 and s.animations["run"]["rows"].size() == 5)
	ck("parser: mirror table", s.mirror == {"W": "E", "SW": "SE", "NW": "NE"}, str(s.mirror))
	ck("parser: default body height 108 when absent", _parse_inline(_base_manifest()).body_height_px == SpriteSet.DEFAULT_BODY_HEIGHT and SpriteSet.DEFAULT_BODY_HEIGHT == 108.0)
	ck("parser: default anchor bottom-centre", _parse_inline(_base_manifest()).foot_anchor == Vector2(16, 32))
	var e := SpriteSet.parse("{nope", "res://x.manifest.json")
	ck("error: invalid JSON is readable", not e.is_valid() and e.first_error().begins_with("invalid JSON"), e.first_error())
	e = SpriteSet.parse("[1]", "res://x.manifest.json")
	ck("error: non-object root", e.first_error() == "manifest root must be a JSON object", e.first_error())
	var d := _base_manifest()
	d["schema"] = 2
	ck("error: wrong schema", _parse_inline(d).first_error().contains("schema"))
	d = _base_manifest()
	d.erase("frame_size")
	ck("error: missing frame_size", _parse_inline(d).first_error().contains("frame_size"))
	d = _base_manifest()
	d["animations"]["idle"]["fps"] = 0
	ck("error: fps must be > 0", _parse_inline(d).first_error().contains("fps must be > 0"))
	d = _base_manifest()
	d["directions"] = ["S", "UP"]
	ck("error: unknown direction named", _parse_inline(d).first_error().contains("UP"))
	d = _base_manifest()
	d["animations"]["idle"]["frames"].erase("W")
	ck("error: missing cardinal without mirror", _parse_inline(d).first_error().contains("cardinal direction W missing"))
	d["mirror"] = {"W": "E"}
	ck("parser: mirror satisfies the missing cardinal", _parse_inline(d).is_valid())
	d = _base_manifest()
	d["animations"]["idle"] = {"fps": 12}
	ck("error: animation needs frames or sheet", _parse_inline(d).first_error().contains("needs either"))
	d = _base_manifest()
	d["animations"] = {}
	ck("error: empty animations", _parse_inline(d).first_error().contains("animations"))
	d = _base_manifest()
	d["unknown_top"] = true
	d["animations"]["idle"]["unknown_anim_key"] = 1
	ck("parser: unknown keys are ignored", _parse_inline(d).is_valid())
	var f := SpriteSet.parse(JSON.stringify(_base_manifest()), TMP.path_join("inline/x.manifest.json"), true)
	ck("error: missing referenced file reported with path", f.first_error().contains("missing file") and f.first_error().contains("a.png"), f.first_error())
	ck("status line: placeholder", SpriteLibrary.status_line(null) == "SPRITES: none (placeholder)")
	ck("status line: OK", SpriteLibrary.status_line(s) == "SPRITES: t32 32x32 OK", SpriteLibrary.status_line(s))
	ck("status line: ERROR", SpriteLibrary.status_line(f).begins_with("SPRITES: x ERROR: "), SpriteLibrary.status_line(f))


func test_resolve_mirror_fallback() -> void:
	var s := _make_set("t_mirror")
	ck("resolve: own direction", s.resolve("idle", "SE") == {"dir": "SE", "flip": false, "fallback": false})
	ck("resolve: W mirrors E", s.resolve("idle", "W") == {"dir": "E", "flip": true, "fallback": false})
	ck("resolve: SW mirrors SE", s.resolve("idle", "SW") == {"dir": "SE", "flip": true, "fallback": false})
	ck("resolve: NW mirrors NE", s.resolve("run", "NW") == {"dir": "NE", "flip": true, "fallback": false})
	ck("resolve: unknown animation -> empty", s.resolve("nope", "S").is_empty())
	var d := _base_manifest()
	d["animations"]["idle"]["frames"]["W"] = ["a.png"]
	var c := _parse_inline(d)
	ck("fallback: NE -> N (vertical cardinal first)", c.resolve("idle", "NE") == {"dir": "N", "flip": false, "fallback": true}, str(c.resolve("idle", "NE")))
	ck("fallback: SE -> S", c.resolve("idle", "SE") == {"dir": "S", "flip": false, "fallback": true})
	ck("fallback: SW -> S", c.resolve("idle", "SW") == {"dir": "S", "flip": false, "fallback": true})
	ck("fallback: NW -> N", c.resolve("idle", "NW") == {"dir": "N", "flip": false, "fallback": true})
	ck("pick_animation: idle / run / sprint", PlayerVisual.pick_animation(s, false, false) == "idle" and PlayerVisual.pick_animation(s, true, false) == "run" and PlayerVisual.pick_animation(s, true, true) == "sprint")
	var only_walk := _base_manifest()
	only_walk["animations"] = {"walk": {"fps": 12, "frames": {"S": ["a.png"], "E": ["a.png"], "N": ["a.png"], "W": ["a.png"]}}}
	var w := _parse_inline(only_walk)
	ck("pick_animation: run falls back to walk, sprint -> walk", PlayerVisual.pick_animation(w, true, false) == "walk" and PlayerVisual.pick_animation(w, true, true) == "walk")


func test_sheet_slicing_and_lazy_cache() -> void:
	ck("sheet_region math (col 3,row 5, 64x32)", SpriteSet.sheet_region(3, 5, Vector2i(64, 32)) == Rect2i(192, 160, 64, 32))
	var s := _make_set("t_lazy")
	ck("lazy: nothing loaded after parse", s.anims_loaded == 0 and s.frames_loaded == 0 and not s.has_frames("run"))
	var f1 := s.get_frames("run")
	ck("lazy: sheet animation built on first use (5 dirs x 3 frames)", f1 != null and f1.get_animation_names().size() == 5 and f1.get_frame_count("E") == 3)
	ck("lazy: only that animation is loaded", s.anims_loaded == 1 and s.frames_loaded == 15 and s.has_frames("run") and not s.has_frames("idle"))
	ck("cache: second call returns the same SpriteFrames", s.get_frames("run") == f1 and s.anims_loaded == 1)
	var at := f1.get_frame_texture("E", 2) as AtlasTexture
	ck("sheet slicing: E row is 2nd row, frame 3 region", at != null and at.region == Rect2(64, 32, 32, 32), str(at.region if at != null else "null"))
	var at_n := f1.get_frame_texture("N", 1) as AtlasTexture
	ck("sheet slicing: N row is 3rd row, frame 2 region", at_n != null and at_n.region == Rect2(32, 64, 32, 32))
	var fi := s.get_frames("idle")
	ck("frames form built (per-frame lists, 2 frames)", fi != null and fi.get_frame_count("S") == 2 and not (fi.get_frame_texture("S", 0) is AtlasTexture))
	ck("metrics counted", s.anims_loaded == 2 and s.frames_loaded == 15 + 10 and s.load_ms > 0.0)
	ck("loading valid files adds no errors", s.is_valid(), str(s.errors))
	ck("unknown animation -> null", s.get_frames("nope") == null)
	# wrong sheet size -> readable error, not a crash
	var base := TMP.path_join("t_badsheet")
	_png(base.path_join("run.png"), 50, 50)
	var d := {"schema": 1, "frame_size": [32, 32], "animations": {"run": {"fps": 12, "sheet": "run.png", "columns": 3, "rows": ["S", "E", "N", "W"]}}}
	var p := base.path_join("t_badsheet.manifest.json")
	_write(p, JSON.stringify(d))
	var b := SpriteSet.parse(FileAccess.get_file_as_string(p), p)
	b.get_frames("run")
	ck("error: sheet size mismatch is reported", b.errors.size() > 0 and b.first_error().contains("expected 96x128"), b.first_error())


func test_discovery() -> void:
	var root_dir := TMP.path_join("disc")
	_write(root_dir.path_join("a/p.manifest.json"), "{}")
	_write(root_dir.path_join("a/p.manifest.json.import"), "")  # duplicate of p after stripping
	_write(root_dir.path_join("b/q.manifest.json.remap"), "")
	_write(root_dir.path_join("c/deep/r.manifest.json.import"), "")
	_write(root_dir.path_join("a/readme.txt"), "x")
	_write(root_dir.path_join("a/notes.json"), "{}")
	_write(root_dir.path_join("ignored/s.manifest.json"), "{}")
	_write(root_dir.path_join("ignored/.gdignore"), "")
	var got := SpriteLibrary.discover_paths(root_dir)
	var want: Array[String] = [root_dir + "/a/p.manifest.json", root_dir + "/b/q.manifest.json", root_dir + "/c/deep/r.manifest.json"]
	ck("discovery: recursive, strips .remap/.import, dedupes, ignores other files and .gdignore dirs", got == want, str(got))
	ck("discovery: missing root -> empty", SpriteLibrary.discover_paths(TMP.path_join("nope")).is_empty())


func test_anchor_stability() -> void:
	var s := _make_set("t_anchor")
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(300, 400)
	await process_frame
	var v := player.visual
	# Independent of what is committed under assets/characters/: clear the set first, then check the fallback.
	v.set_sprite_set(null)
	ck("visual: placeholder is shown when no valid set is selected", v.sprite_set == null and v.placeholder.visible and not v.actor.visible)
	var empty_lib := SpriteLibrary.new()
	empty_lib.scan(TMP.path_join("no_such_assets"))
	ck("library: an empty tree has no valid set (placeholder fallback)", empty_lib.sets.is_empty() and empty_lib.first_valid() == null)
	v.set_sprite_set(s)
	ck("visual: valid set swaps placeholder out", v.actor.visible and not v.placeholder.visible)
	v.set_pose(Vector2.RIGHT, false, true)
	var anchor_run: Vector2 = v.actor.sprite.global_transform * s.foot_anchor
	var pos_run := v.actor.sprite.global_position
	ck("visual: moving -> run", v.last_anim == "run")
	v.set_pose(Vector2.RIGHT, true, true)
	var anchor_sprint: Vector2 = v.actor.sprite.global_transform * s.foot_anchor
	ck("visual: sprint -> sprint", v.last_anim == "sprint")
	ck("anchor: foot anchor lies on the player origin (run)", anchor_run.is_equal_approx(player.global_position), str(anchor_run))
	ck("anchor: unchanged run <-> sprint", anchor_sprint.is_equal_approx(anchor_run) and v.actor.sprite.global_position.is_equal_approx(pos_run))
	v.set_pose(Vector2.LEFT, true, true)
	var anchor_w: Vector2 = v.actor.sprite.global_transform * s.foot_anchor
	ck("anchor: unchanged when mirrored (W flip)", v.actor.flip and anchor_w.is_equal_approx(player.global_position), str(anchor_w))
	v.set_pose(Vector2.LEFT, false, false)
	var anchor_idle: Vector2 = v.actor.sprite.global_transform * s.foot_anchor
	ck("anchor: unchanged for idle", v.last_anim == "idle" and anchor_idle.is_equal_approx(player.global_position))
	var collider := player.get_node("CollisionShape2D") as CollisionShape2D
	ck("collision footprint stays fixed while frames swap", collider.position == Vector2(0, -WorldScale.FOOTPRINT.y * 0.5) and (collider.shape as RectangleShape2D).size == WorldScale.FOOTPRINT)
	v.set_sprite_set(null)
	ck("visual: clearing the set returns to the placeholder", v.placeholder.visible and not v.actor.visible)
	player.queue_free()
	await process_frame


# ------------------------------------------------------------------ gameplay (main scene)
func _hold(actions: Array, frames: int) -> void:
	for a: String in actions:
		Input.action_press(a)
	for i in frames:
		await physics_frame
	for a: String in actions:
		Input.action_release(a)


func _place(p: PlayerController, pos: Vector2) -> void:
	p.global_position = pos
	p.velocity = Vector2.ZERO


func test_main_scene_and_movement() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	ck("main scene loads", packed != null)
	if packed == null:
		return
	var main := packed.instantiate()
	ck("main scene instantiates", main != null)
	root.add_child(main)
	for i in 5:
		await process_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	ck("main scene has arena, player, HUD and lab", arena != null and player != null and main.get_node_or_null("DebugHud") != null and main.get_node_or_null("AnimationLab") != null)
	if arena == null or player == null:
		return
	var ground := arena.get_node_or_null("Ground") as Node2D
	ck("ground is a lower-z child so y<0 actors are not hidden under it", ground != null and ground.z_index < 0 and player.z_index == 0)
	ck("player starts at the spawn marker", player.global_position.distance_to(arena.spawn.global_position) < 1.0)
	ck("player starts idle", player.state == PlayerController.State.IDLE)

	# right move
	_place(player, Vector2(-600, 100))
	var x0 := player.global_position.x
	await _hold(["move_right"], 20)
	ck("moves right while move_right is held", player.global_position.x > x0 + 20.0, "dx=%.1f" % (player.global_position.x - x0))
	ck("state is MOVE while walking", player.get_state_name() == "MOVE", player.get_state_name())

	# walk vs sprint speed
	_place(player, Vector2(-600, 100))
	await _hold(["move_right"], 40)
	var walk_v := player.velocity.length()
	_place(player, Vector2(-600, 100))
	await _hold(["move_right", "sprint"], 40)
	var sprint_v := player.velocity.length()
	ck("sprint is faster than walk", sprint_v > walk_v + (player.sprint_speed - player.walk_speed) * 0.5, "walk=%.1f sprint=%.1f" % [walk_v, sprint_v])
	ck("walk speed reaches walk_speed", is_equal_approx(walk_v, player.walk_speed), str(walk_v))

	# diagonal not faster than straight
	_place(player, Vector2(-600, 100))
	await _hold(["move_right", "move_down"], 40)
	var diag_v := player.velocity.length()
	ck("diagonal speed is not greater than straight speed", diag_v <= walk_v + 0.5, "diag=%.1f straight=%.1f" % [diag_v, walk_v])
	await _hold([], 30)  # friction to a stop

	# wall blocks
	var wall: Array = TrainingArena.BLOCKS[1]  # derived from WorldScale: [bottom-centre, footprint, height]
	var wall_face: float = (wall[0] as Vector2).x - (wall[1] as Vector2).x * 0.5
	var wall_start := wall_face - 80.0
	_place(player, Vector2(wall_start, (wall[0] as Vector2).y - (wall[1] as Vector2).y * 0.5))
	await _hold(["move_right"], 60)
	var px := player.global_position.x
	ck("a wall (block) blocks the player", px > wall_start and px < wall_face, "x=%.1f face=%.1f" % [px, wall_face])
	# blossom tree trunks are solid: walk west-to-east and north-to-south into each base
	for ti in WorldScale.TREE_POSITIONS.size():
		var tp: Vector2 = WorldScale.TREE_POSITIONS[ti]
		var half := WorldScale.TREE_TRUNK_FOOTPRINT * 0.5
		var mid_y := tp.y - half.y
		_place(player, Vector2(tp.x - half.x - 90.0, mid_y))
		await _hold(["move_right"], 60)
		ck("tree %d trunk blocks the player (from west)" % ti, player.global_position.x < tp.x - half.x + 1.0, "x=%.1f left=%.1f" % [player.global_position.x, tp.x - half.x])
		_place(player, Vector2(tp.x, tp.y + 90.0))
		await _hold(["move_up"], 60)
		ck("tree %d trunk blocks the player (from south)" % ti, player.global_position.y > tp.y - 1.0, "y=%.1f base=%.1f" % [player.global_position.y, tp.y])
		await _hold([], 20)
	var nav_blocked := true
	for tp in WorldScale.TREE_POSITIONS:
		nav_blocked = nav_blocked and not arena.nav.is_walkable(tp + Vector2(0, -20))
	ck("bandit nav treats tree bases as solid", nav_blocked)
	_place(player, Vector2(arena.bounds.end.x - 150.0, 0))
	await _hold(["move_right"], 90)
	ck("arena bounds wall blocks the player", player.global_position.x <= arena.bounds.end.x, "x=%.1f" % player.global_position.x)

	# camera limits
	var cam := player.camera
	var b := arena.get_bounds()
	ck("camera limits match arena bounds (top has head room)", cam.limit_left == int(b.position.x) and cam.limit_top == int(b.position.y - WorldScale.CAMERA_HEADROOM) and cam.limit_right == int(b.end.x) and cam.limit_bottom == int(b.end.y + WorldScale.CAMERA_FOOTROOM), "%d %d %d %d" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ jump / dodge chaining (fluid movement)
func test_jump_and_dodge_chaining() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	ck("jump/dodge: scene has arena and player", arena != null and player != null)
	if arena == null or player == null:
		main.queue_free()
		return

	# Hold `action` for a few frames then release (a same-frame press+release is faster than this
	# headless harness can reliably register as a just_pressed edge; a real keypress always spans
	# several frames). Samples state every frame; returns [reached_target, saw_idle_first, frames].
	var _tap := func(action: String, target: PlayerController.State, max_frames: int) -> Array:
		Input.action_press(action)
		var saw_idle := false
		var reached := false
		for i in max_frames:
			await physics_frame
			if player.state == PlayerController.State.IDLE:
				saw_idle = true
			if player.state == target:
				reached = true
				Input.action_release(action)
				return [reached, saw_idle]
		Input.action_release(action)
		return [reached, saw_idle]

	# Fully clears FSM + buffer state between scenarios so one block's input never bleeds into the next.
	var _reset := func(pos: Vector2) -> void:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		Input.action_release("sprint")
		Input.action_release("dodge")
		Input.action_release("jump")
		player._dodge_buffer = 0.0
		player._jump_buffer = 0.0
		player._action_timer = 0.0
		player.state = PlayerController.State.IDLE
		_place(player, pos)

	# Idle -> Run -> Jump -> Run: state must go straight from MOVE to JUMP (never an idle detour), and
	# momentum must never collapse toward 0 across the transition.
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	var run_speed := player.velocity.length()
	ck("run builds up to walk_speed before jumping", is_equal_approx(run_speed, player.walk_speed), str(run_speed))
	var r1: Array = await _tap.call("jump", PlayerController.State.JUMP, 8)
	ck("jump fires directly from MOVE (no idle detour)", r1[0] and not r1[1], str(r1))
	ck("jump preserves run momentum on entry (no stop-before-jump)", player.velocity.length() > run_speed * 0.9, str(player.velocity.length()))
	var min_v_during_jump := player.velocity.length()
	var jump_frames := 0
	while player.state == PlayerController.State.JUMP and jump_frames < 150:
		await physics_frame
		jump_frames += 1
		min_v_during_jump = minf(min_v_during_jump, player.velocity.length())
	ck("velocity never collapses toward 0 while airborne with input held", min_v_during_jump > player.jump_air_speed_cap * 0.9, str(min_v_during_jump))
	ck("landing resumes MOVE immediately with input held (no idle frame)", player.state == PlayerController.State.MOVE, player.get_state_name())
	Input.action_release("move_right")

	# Sprint -> Jump -> Land -> Sprint: same guarantee at sprint speed; landing resumes SPRINT (not MOVE).
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 20:
		await physics_frame
	var sprint_v := player.velocity.length()
	ck("sprint builds up to sprint_speed before jumping", is_equal_approx(sprint_v, player.sprint_speed), str(sprint_v))
	var r2: Array = await _tap.call("jump", PlayerController.State.JUMP, 8)
	ck("jump fires directly from SPRINT (no idle detour)", r2[0] and not r2[1], str(r2))
	ck("jump preserves sprint momentum on entry", player.velocity.length() > sprint_v * 0.9, str(player.velocity.length()))
	var jf := 0
	while player.state == PlayerController.State.JUMP and jf < 150:
		await physics_frame
		jf += 1
	ck("landing resumes SPRINT immediately with sprint+move held", player.state == PlayerController.State.SPRINT, player.get_state_name())
	Input.action_release("move_right")
	Input.action_release("sprint")

	# Run -> Dodge -> Run: a real directional burst that displaces the player, not just an animation,
	# recovering toward run speed (not a dead stop) while input is still held.
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	var dodge_start_x := player.global_position.x
	var r3: Array = await _tap.call("dodge", PlayerController.State.DODGE, 8)
	ck("dodge fires directly from MOVE (no idle detour)", r3[0] and not r3[1], str(r3))
	var burst_v := player.velocity.length()
	ck("dodge is a Body Flicker: an instant displacement, no lunge or slide (velocity stays 0)", burst_v == 0.0 and player.flicker_count >= 1, "v=%s" % burst_v)
	var dodge_frames := 0
	while player.state == PlayerController.State.DODGE and dodge_frames < 60:
		await physics_frame
		dodge_frames += 1
	ck("dodge actually displaces the player through the world", player.global_position.x > dodge_start_x + player.flicker_distance * 0.9, str(player.global_position.x - dodge_start_x))
	ck("dodge recovery blends back into MOVE immediately with input held", player.state == PlayerController.State.MOVE, player.get_state_name())
	Input.action_release("move_right")

	# Sprint -> Dodge -> Sprint: same burst/displacement guarantee, recovering into SPRINT.
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 20:
		await physics_frame
	var r4: Array = await _tap.call("dodge", PlayerController.State.DODGE, 8)
	ck("sprint-dodge fires directly from SPRINT (no idle detour)", r4[0] and not r4[1], str(r4))
	var sdodge_frames := 0
	while player.state == PlayerController.State.DODGE and sdodge_frames < 60:
		await physics_frame
		sdodge_frames += 1
	ck("sprint-dodge recovery blends back into SPRINT immediately with sprint+move held", player.state == PlayerController.State.SPRINT, player.get_state_name())
	Input.action_release("move_right")
	Input.action_release("sprint")

	# Releasing movement input mid-dodge: recovery target becomes 0, so the dodge eases to a stop and
	# lands IDLE rather than staying stuck at burst speed or freezing mid-pose.
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	Input.action_press("dodge")
	for i in 3:
		await physics_frame
	Input.action_release("dodge")
	Input.action_release("move_right")
	var release_frames := 0
	while player.state == PlayerController.State.DODGE and release_frames < 60:
		await physics_frame
		release_frames += 1
	ck("dodge recovery with input released eases to IDLE, not a frozen pose", player.state == PlayerController.State.IDLE, player.get_state_name())

	# Dodge/jump into a wall: must be blocked at the wall face, never clip through it.
	var wall: Array = TrainingArena.BLOCKS[1]
	var wall_face: float = (wall[0] as Vector2).x - (wall[1] as Vector2).x * 0.5
	var wall_y: float = (wall[0] as Vector2).y - (wall[1] as Vector2).y * 0.5
	await _reset.call(Vector2(wall_face - 60.0, wall_y))
	Input.action_press("move_right")
	for i in 5:
		await physics_frame
	Input.action_press("dodge")
	for i in 3:
		await physics_frame
	Input.action_release("dodge")
	for i in 40:
		await physics_frame
	Input.action_release("move_right")
	ck("dodging into a wall does not clip through it", player.global_position.x < wall_face + 1.0, "x=%.1f face=%.1f" % [player.global_position.x, wall_face])

	await _reset.call(Vector2(wall_face - 60.0, wall_y))
	Input.action_press("move_right")
	for i in 5:
		await physics_frame
	Input.action_press("jump")
	for i in 3:
		await physics_frame
	Input.action_release("jump")
	for i in 100:
		await physics_frame
	Input.action_release("move_right")
	ck("jumping into a wall does not clip through it (collision preserved while airborne)", player.global_position.x < wall_face + 1.0, "x=%.1f face=%.1f" % [player.global_position.x, wall_face])

	# Run -> Jump -> Dodge, when the action rules permit it: a dodge press buffered near the tail end
	# of a jump is remembered and fires the instant the jump ends, instead of being silently dropped.
	await _reset.call(Vector2(-900, 100))
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	var r5: Array = await _tap.call("jump", PlayerController.State.JUMP, 8)
	ck("jump fires before buffering a chained dodge", r5[0], str(r5))
	var jump_dur: float = player._action_duration
	var wait_frames := int(maxf(jump_dur * Engine.physics_ticks_per_second - 4.0, 0.0))
	for i in wait_frames:
		await physics_frame
	Input.action_press("dodge")
	for i in 3:
		await physics_frame
	Input.action_release("dodge")
	var saw_dodge := false
	var chase_frames := 0
	while chase_frames < 30:
		await physics_frame
		chase_frames += 1
		if player.state == PlayerController.State.DODGE:
			saw_dodge = true
			break
	ck("a dodge press buffered near the end of a jump fires the instant the jump ends", saw_dodge, player.get_state_name())
	Input.action_release("move_right")

	main.queue_free()
	await process_frame




# ------------------------------------------------------------------ lab controls + pause (real AnimationLab / DebugHud)
func _snap(lab: AnimationLab) -> Array:
	return [lab.sel_index, lab.anim_id, lab.dir_mode, lab.dir_index, lab.speed_index, lab.anim_paused, lab.compare, lab.zoom_index, lab.overlay_on.duplicate(), lab.lab_on]


func _restore(lab: AnimationLab, s: Array) -> void:
	lab._select_set(s[0])
	lab.anim_id = s[1]
	lab.dir_mode = s[2]
	lab.dir_index = s[3]
	lab.speed_index = s[4]
	lab.anim_paused = s[5]
	lab.compare = s[6]
	lab.set_zoom_index(s[7])
	lab.overlay_on = (s[8] as Dictionary).duplicate()
	lab._set_lab(s[9])


func _press(node: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	node._unhandled_input(ev)


func _wheel(lab: AnimationLab, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	lab._unhandled_input(ev)


func test_lab_and_pause() -> void:
	var lib := SpriteLibrary.get_instance()
	var saved: Array[SpriteSet] = lib.sets.duplicate()
	lib.sets.clear()
	lib.sets.append(_make_set("t_lab_a"))
	lib.sets.append(_make_set("t_lab_b"))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var lab := main.get_node("AnimationLab") as AnimationLab
	var hud := main.get_node("DebugHud")
	var player := main.get_node("TrainingArena/Player") as PlayerController
	ck("lab: real art is selected without opening the panel", player.visual.sprite_set == lib.sets[0] and not lab.lab_on and not lab.stands[0].visible)
	_press(lab, "dbg_toggle_lab")
	ck("lab: explicit open shows the selected art stand", lab.lab_on and lab.stands[0].visible)
	var base := _snap(lab)

	# playback speed: clamps at both ends and reaches the stand's AnimatedSprite2D.speed_scale
	for i in 5:
		_press(lab, "dbg_speed_down")
	await process_frame
	ck("lab speed: clamps at 0.25x and reaches speed_scale", lab.speed_index == 0 and AnimationLab.SPEEDS[lab.speed_index] == 0.25 and is_equal_approx(lab.stands[0].actor.sprite.speed_scale, 0.25), str(lab.stands[0].actor.sprite.speed_scale))
	for i in 8:
		_press(lab, "dbg_speed_up")
	await process_frame
	ck("lab speed: clamps at 2.0x and reaches speed_scale", lab.speed_index == AnimationLab.SPEEDS.size() - 1 and is_equal_approx(lab.stands[0].actor.sprite.speed_scale, 2.0), str(lab.stands[0].actor.sprite.speed_scale))
	_restore(lab, base)

	# direction mode cycle (V): FOLLOW -> FIXED -> SPIN -> FOLLOW
	var modes: Array = []
	for i in 3:
		_press(lab, "dbg_dir_follow")
		modes.append(lab.dir_mode)
	ck("lab direction mode: V cycles FIXED, SPIN, FOLLOW", modes == [AnimationLab.DirMode.FIXED, AnimationLab.DirMode.SPIN, AnimationLab.DirMode.FOLLOW], str(modes))
	_restore(lab, base)
	_press(lab, "dbg_dir_next")
	ck("lab direction: ; ' step switches to FIXED and moves one heading", lab.dir_mode == AnimationLab.DirMode.FIXED and lab.current_dir_name() == "SE", lab.current_dir_name())
	_restore(lab, base)

	# mouse wheel zoom: one notch = one entry of the lab zoom list (whole and half steps), clamped at both ends
	_wheel(lab, MOUSE_BUTTON_WHEEL_UP)
	ck("lab zoom: wheel up -> native 1x on the camera", lab.zoom_index == 1 and player.camera.zoom == Vector2.ONE)
	_wheel(lab, MOUSE_BUTTON_WHEEL_UP)
	ck("lab zoom: the next wheel notch is the 1.25x quarter step", lab.zoom_index == 2 and player.camera.zoom == Vector2(1.25, 1.25))
	for i in 3:
		_wheel(lab, MOUSE_BUTTON_WHEEL_DOWN)
	ck("lab zoom: wheel down clamps at the wide baseline", lab.zoom_index == 0 and is_equal_approx(player.camera.zoom.x, CameraPreset.zoom_for(CameraPreset.WIDE)))
	var wheel_seen: Array[float] = []
	for i in 15:
		_wheel(lab, MOUSE_BUTTON_WHEEL_UP)
		wheel_seen.append(player.camera.zoom.x)
	ck("lab zoom: the wheel walks 1, 1.25, 1.5 and stays at the 1.5x ceiling", str(wheel_seen) == str([1.0, 1.25, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), str(wheel_seen))
	ck("lab zoom: wheel up clamps at 1.5x (the last of the 4 list entries)", lab.zoom_index == 3 and player.camera.zoom == Vector2(1.5, 1.5))
	var wheel_back: Array[float] = []
	for i in 5:
		_wheel(lab, MOUSE_BUTTON_WHEEL_DOWN)
		wheel_back.append(player.camera.zoom.x)
	ck("lab zoom: the wheel walks back 1.25, 1, baseline", str(wheel_back.slice(0, 2)) == str([1.25, 1.0]) and lab.zoom_index == 0 and is_equal_approx(wheel_back[4], CameraPreset.zoom_for(CameraPreset.WIDE)), str(wheel_back))

	# every panel button does exactly what its dbg_* key does
	var rows: Array = lab._panel.get_child(0).get_children()
	var grid := rows[8] as GridContainer
	var pairs: Array = [  # [button, action]
		[rows[0].get_child(1), "dbg_set_prev"], [rows[0].get_child(2), "dbg_set_next"],
		[rows[1].get_child(1), "dbg_anim_prev"], [rows[1].get_child(2), "dbg_anim_next"],
		[rows[2].get_child(1), "dbg_dir_prev"], [rows[2].get_child(2), "dbg_dir_next"],
		[rows[3].get_child(1), "dbg_dir_follow"], [rows[3].get_child(2), "dbg_dir_follow"],
		[rows[4].get_child(1), "dbg_speed_down"], [rows[4].get_child(2), "dbg_speed_up"],
		[rows[5].get_child(1), "dbg_anim_pause"], [rows[5].get_child(2), "dbg_anim_step"],
		[rows[6].get_child(1), "dbg_compare"], [rows[6].get_child(2), "dbg_compare"],
		[rows[7].get_child(1), "dbg_zoom_cycle"], [rows[7].get_child(2), "dbg_zoom_cycle"],
		[lab._lab_button, "dbg_toggle_lab"],
	]
	for i in grid.get_child_count():
		pairs.append([grid.get_child(i), "dbg_overlay_" + ["iso_grid", "square_grid", "anchor", "footprint", "ruler", "bbox"][i]])
	var parity_ok := true
	var parity_bad: Array[String] = []
	for p: Array in pairs:
		_restore(lab, base)
		_press(lab, p[1])
		var by_key := _snap(lab)
		_restore(lab, base)
		(p[0] as Button).pressed.emit()
		var by_button := _snap(lab)
		if by_key == base or by_key != by_button:
			parity_ok = false
			parity_bad.append("%s (%s)" % [p[1], (p[0] as Button).text])
	_restore(lab, base)
	ck("lab: all %d panel buttons change state exactly like their dbg_* key" % pairs.size(), parity_ok and pairs.size() == 23, str(parity_bad))

	# pause (Esc): tree pauses, gameplay freezes, HUD keeps processing, label shows, second press resumes
	ck("pause: HUD is process_mode ALWAYS, player is not", hud.process_mode == Node.PROCESS_MODE_ALWAYS and not paused)
	_press(hud, "pause")
	ck("pause: Esc pauses the tree and shows PAUSED", paused and hud._paused.visible and hud.can_process() and not player.can_process())
	var x_before := player.global_position.x
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	Input.action_release("move_right")
	ck("pause: player does not move while paused", is_equal_approx(player.global_position.x, x_before), "dx=%.2f" % (player.global_position.x - x_before))
	_press(hud, "pause")
	ck("pause: second Esc resumes and hides PAUSED", not paused and not hud._paused.visible)
	paused = false

	main.queue_free()
	await process_frame
	lib.sets.clear()
	lib.sets.append_array(saved)


# ------------------------------------------------------------------ camera framing (wide gameplay view, PR #12)
func test_camera_framing() -> void:
	var lib := SpriteLibrary.get_instance()
	var saved: Array[SpriteSet] = lib.sets.duplicate()
	lib.sets.clear()
	lib.sets.append(_make_set("t_cam"))  # a valid set so the lab opens at scene start
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var lab := main.get_node("AnimationLab") as AnimationLab
	var arena := main.get_node("TrainingArena") as TrainingArena
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var cam := player.camera
	var base := CameraPreset.zoom_for(CameraPreset.WIDE)  # the wide preset, read from the preset table

	# baseline zoom at scene start
	ck("camera: the wide preset in the table is 0.665 (locked) and the default preset is wide", is_equal_approx(base, 0.665) and is_equal_approx(float(CameraPreset.TABLE[CameraPreset.WIDE]["zoom"]), 0.665) and CameraPreset.DEFAULT_ID == CameraPreset.WIDE and CameraPreset.active_id() == "wide")
	ck("camera: baseline zoom equals 0.665 within 1e-6 at scene start", absf(cam.zoom.x - 0.665) < 1e-6 and absf(cam.zoom.y - 0.665) < 1e-6, "zoom=%s expected 0.665000" % cam.zoom)

	# visible rect = pre-scale view * SCALE, and it fits inside the arena
	var vp := root.get_visible_rect().size
	var view := vp / cam.zoom.x
	ck("camera: viewport is the 1280x720 base size", vp == Vector2(1280, 720), str(vp))
	ck("camera: visible world rect at baseline is 1924.8x1082.7", view.is_equal_approx(Vector2(1280.0 / 0.665, 720.0 / 0.665)), "view=%s" % view)
	ck("camera: visible rect fits inside ARENA_BOUNDS", view.x <= WorldScale.ARENA_BOUNDS.size.x and view.y <= WorldScale.ARENA_BOUNDS.size.y, "view=%s bounds=%s" % [view, WorldScale.ARENA_BOUNDS.size])

	# camera limits equal the arena bounds (CAMERA_HEADROOM above the top, CAMERA_FOOTROOM below the bottom)
	var b := WorldScale.ARENA_BOUNDS
	ck("camera: arena.get_bounds() is WorldScale.ARENA_BOUNDS", arena.get_bounds() == b)
	ck("camera: limits left/right equal the arena bounds", cam.limit_left == int(b.position.x) and cam.limit_right == int(b.end.x), "%d %d" % [cam.limit_left, cam.limit_right])
	ck("camera: limit_bottom is the arena bottom plus CAMERA_FOOTROOM", cam.limit_bottom == int(b.end.y + WorldScale.CAMERA_FOOTROOM), str(cam.limit_bottom))
	ck("camera: limit_top is the arena top minus CAMERA_HEADROOM", cam.limit_top == int(b.position.y - WorldScale.CAMERA_HEADROOM), str(cam.limit_top))
	ck("camera: limited area is at least as large as the visible rect (no void can show)", (cam.limit_right - cam.limit_left) >= view.x and (cam.limit_bottom - cam.limit_top) >= view.y)

	# lab zoom list and labels (whole steps stay, half steps in between, the first Z from the baseline is exactly 1.0)
	var zl := AnimationLab.zoom_list(base)
	ck("lab zoom list is [baseline, 1, 1.25, 1.5]", zl.size() == 4 and zl[0] == base and zl.slice(1) == [1.0, 1.25, 1.5], str(zl))
	var step_labels: Array[String] = []
	for i in zl.size():
		step_labels.append(AnimationLab.zoom_label(i, base))
	ck("lab zoom labels: 'wide 0.67x' then 1x 1.25x 1.5x", str(step_labels) == str(["wide 0.67x", "1x", "1.25x", "1.5x"]), str(step_labels))

	# opening the lab must not change the camera; the panel shows the real zoom
	var zoom_value := lab._value_labels["zoom"] as Label
	ck("lab: closed at scene start with baseline zoom and label", not lab.lab_on and lab.zoom_index == 0 and is_equal_approx(cam.zoom.x, base) and zoom_value.text == "wide 0.67x", "%s idx=%d" % [zoom_value.text, lab.zoom_index])
	_press(lab, "dbg_toggle_lab")
	ck("lab: opening explicitly leaves the camera at baseline", lab.lab_on and is_equal_approx(cam.zoom.x, base) and zoom_value.text == "wide 0.67x")

	# Z cycles 1x, 1.25x, 1.5x ... 4x and wraps to baseline; label and camera agree at every step
	var seen: Array[float] = []
	var labels: Array[String] = []
	for i in 9:
		_press(lab, "dbg_zoom_cycle")
		seen.append(cam.zoom.x)
		labels.append(zoom_value.text)
	ck("lab: the first Z from the baseline is exactly 1.0", seen[0] == 1.0, str(seen))
	ck("lab: Z cycles 1,1.25,1.5, baseline, 1 on the camera", str(seen.slice(0, 3)) == str([1.0, 1.25, 1.5]) and is_equal_approx(seen[3], base) and seen[4] == 1.0, str(seen))
	ck("lab: panel label matches the real zoom at every step", str(labels.slice(0, 5)) == str(["1x", "1.25x", "1.5x", "wide 0.67x", "1x"]), str(labels))
	# opening while zoomed keeps the zoom; closing restores baseline (from a quarter step and from a whole step)
	# after the Z-walk loop above (9 presses on a 4-entry cycle), lab is at zoom_index=1 (1.0x). one more press lands at idx2 = 1.25x.
	_press(lab, "dbg_zoom_cycle")  # 1x(idx1) -> 1.25x(idx2)
	var zoom_half := cam.zoom.x
	_press(lab, "dbg_toggle_lab")  # close
	ck("lab: closing the lab at a quarter step restores the baseline zoom", not lab.lab_on and lab.zoom_index == 0 and is_equal_approx(cam.zoom.x, base) and zoom_half == 1.25, "zoom=%s" % cam.zoom)
	_press(lab, "dbg_toggle_lab")  # open
	ck("lab: re-opening does not change the camera", lab.lab_on and is_equal_approx(cam.zoom.x, base))
	for i in 3:
		_press(lab, "dbg_zoom_cycle")  # 1x, 1.25x, 1.5x (the ceiling)
	var zoom_2x := cam.zoom.x
	_press(lab, "dbg_toggle_lab")  # close
	ck("lab: closing the lab at the 1.5x ceiling restores the baseline zoom", not lab.lab_on and lab.zoom_index == 0 and is_equal_approx(cam.zoom.x, base) and zoom_2x == 1.5, "zoom=%s" % cam.zoom)
	_press(lab, "dbg_toggle_lab")  # open
	_wheel(lab, MOUSE_BUTTON_WHEEL_UP)  # baseline -> 1x
	_wheel(lab, MOUSE_BUTTON_WHEEL_UP)  # 1x -> 1.25x
	_wheel(lab, MOUSE_BUTTON_WHEEL_UP)  # 1.25x -> 1.5x
	var wheel_half := cam.zoom.x
	_press(lab, "dbg_toggle_lab")
	ck("lab: closing after a wheel zoom (to the 1.5x half step) restores the baseline", wheel_half == 1.5 and is_equal_approx(cam.zoom.x, base) and lab.zoom_index == 0)
	# __SHINOBI_STATE__ framing fields (WebBridge is inert outside the browser, so test the publisher's helper + source)
	var bridge_script := load("res://scripts/web/web_bridge.gd")
	var fr: Dictionary = bridge_script.camera_framing(cam.zoom.x, vp)
	ck("state: camera_framing publishes zoom/view_w/view_h at baseline", absf(fr["zoom"] - base) < 1e-6 and absf(fr["view_w"] - 1280.0 / 0.665) < 0.01 and absf(fr["view_h"] - 720.0 / 0.665) < 0.01, str(fr))
	var fr2: Dictionary = bridge_script.camera_framing(2.0, Vector2(1280, 720))
	ck("state: camera_framing at 2x gives a 640x360 view", fr2 == {"zoom": 2.0, "view_w": 640.0, "view_h": 360.0}, str(fr2))
	var src := FileAccess.get_file_as_string("res://scripts/web/web_bridge.gd")
	var fields_ok := true
	for f: String in ["frame", "x", "y", "state", "sprinting", "fps", "zoom", "view_w", "view_h"]:
		if not src.contains("_state.%s = " % f):
			fields_ok = false
	ck("state: WebBridge still publishes frame,x,y,state,sprinting,fps plus zoom,view_w,view_h", fields_ok)

	# caption sizing: figure caption (local scale 1.895) and block caption floor reach the minimum screen size at the wide zoom
	var fig_px := WorldScale.caption_font_size(8, base, 1.895) * 1.895 * base
	var blk_px := WorldScale.caption_font_size(5, base) * base
	ck("caption: figure caption is at least MIN_CAPTION_SCREEN_PX on screen at baseline", fig_px >= WorldScale.MIN_CAPTION_SCREEN_PX, "%.2f px" % fig_px)
	ck("caption: block caption floor is at least MIN_CAPTION_SCREEN_PX on screen at baseline", blk_px >= WorldScale.MIN_CAPTION_SCREEN_PX, "%.2f px" % blk_px)
	ck("caption: never smaller than the base size at native zoom", WorldScale.caption_font_size(8, 1.0) == 8 and WorldScale.caption_font_size(5, 4.0) == 5)

	main.queue_free()
	await process_frame
	lib.sets.clear()
	lib.sets.append_array(saved)
