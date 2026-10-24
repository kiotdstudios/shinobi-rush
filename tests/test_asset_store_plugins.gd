extends RefCounted
## Four free Godot Asset Store addons (owner 2026-10-23: "add all under with considering" --
## Juicee, Dialogue Manager, Weather FX Free, Breakable 2D Sprites). Called from tests/run_tests.gd.
## Covers: each addon's code actually loaded (class/autoload present, callable), and the Web-export
## safety properties that made these four safe to add in the first place:
##   - no native GDExtension binaries shipped by any of them (checked at the SOURCE level here;
##     the real binary-absence was already verified by hand against the downloaded zips before
##     ever copying them into the repo -- see the order for that evidence)
##   - export_presets.cfg excludes each addon's non-shipped demo/test-scene/sample-art folder
## Lit (2D Lighting Engine) was investigated and DELIBERATELY NOT added: its own store page states
## "Requires Godot 4.4+ on the Forward+ renderer. (Mobile/Compatibility aren't supported.)" and this
## project's project.godot is explicitly gl_compatibility (renderer/rendering_method="gl_compatibility"
## for both desktop and mobile) -- Lit could not function here at all, on Web or otherwise.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_no_native_binaries_anywhere_under_addons()
	_test_export_filter_excludes_demo_content()
	_test_plugin_cfgs_present_and_enabled()
	await _test_autoloads_and_classes(tree_root)


## The decisive Web/WASM-export safety check: a GDExtension-based addon ships a .gdextension
## manifest and/or compiled .dll/.so/.dylib/.wasm binaries, which generally do not run in Godot's
## Web export unless the publisher specifically built an emscripten target (none of these four do).
## Also scans for .cs: this project has no Mono/.NET Godot build (confirmed the hard way -- the
## first version of this PR shipped Dialogue Manager's optional C# wrapper scripts/scenes
## unmodified, and real CI failed with "No loader found for resource ... (expected type: Script)"
## for every .cs file referenced by a .tscn, because this editor/export template can't load C# at
## all). All four addons added this session are pure GDScript + shaders/scenes/resources once their
## optional C# wrappers are stripped -- verified here by scanning every file actually present under
## addons/, not just trusting the asset page text.
func _test_no_native_binaries_anywhere_under_addons() -> void:
	var forbidden_exts := ["gdextension", "dll", "so", "dylib", "wasm", "cs"]
	var offenders: Array[String] = []
	var dir := DirAccess.open("res://addons")
	if dir == null:
		ck.call("asset store plugins: res://addons exists", false)
		return
	_scan_for_native(dir, "res://addons", forbidden_exts, offenders)
	ck.call("asset store plugins: zero native GDExtension binaries or C# scripts anywhere under addons/ (Web export + no-Mono-build safe)", offenders.is_empty(), str(offenders))



func _scan_for_native(dir: DirAccess, path: String, exts: Array, out: Array[String]) -> void:
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var full := path + "/" + entry
		if dir.current_is_dir():
			var sub := DirAccess.open(full)
			if sub != null:
				_scan_for_native(sub, full, exts, out)
		else:
			var ext := entry.get_extension().to_lower()
			if ext in exts:
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _test_export_filter_excludes_demo_content() -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	for needle in ["addons/weather_fx/demo/*", "addons/dialogue_manager/example_balloon/*"]:
		ck.call("asset store plugins: export_presets.cfg excludes %s from the shipped build" % needle, cfg.contains(needle))


func _test_plugin_cfgs_present_and_enabled() -> void:
	var expect := {
		"res://addons/juicee/plugin.cfg": "Juicee",
		"res://addons/dialogue_manager/plugin.cfg": "Dialogue Manager",
		"res://addons/breakable_2d_sprites/plugin.cfg": "Breakable 2D Sprites",
	}
	var project_cfg := FileAccess.get_file_as_string("res://project.godot")
	for cfg_path: String in expect:
		ck.call("asset store plugins: %s exists" % cfg_path, FileAccess.file_exists(cfg_path))
		ck.call("asset store plugins: %s is listed in project.godot's enabled editor_plugins" % cfg_path, project_cfg.contains(cfg_path))
		if FileAccess.file_exists(cfg_path):
			var cfg := ConfigFile.new()
			cfg.load(cfg_path)
			ck.call("asset store plugins: %s plugin.cfg name matches (%s)" % [cfg_path, expect[cfg_path]], cfg.get_value("plugin", "name", "") == expect[cfg_path])
	# Weather FX is deliberately NOT an EditorPlugin (no plugin.cfg) -- it's a plain `class_name`
	# utility script, auto-registered project-wide with no enable step. Confirm that's true, not
	# an oversight: it would be a bug if a later update of the addon silently added one that we
	# forgot to wire into [editor_plugins].
	ck.call("asset store plugins: Weather FX genuinely has no plugin.cfg (confirms it needs no enable step, not an oversight)", not FileAccess.file_exists("res://addons/weather_fx/plugin.cfg"))


func _test_autoloads_and_classes(tree_root: Node) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 4:
		await main.get_tree().process_frame
	var root := main.get_tree().root

	var juicee := root.get_node_or_null("Juicee")
	ck.call("asset store plugins: Juicee autoload is present", juicee != null)
	if juicee != null:
		ck.call("asset store plugins: Juicee has a callable shake_camera()", juicee.has_method("shake_camera"))
		ck.call("asset store plugins: Juicee has a callable hit_stop()", juicee.has_method("hit_stop"))

	var dm := root.get_node_or_null("DialogueManager")
	ck.call("asset store plugins: DialogueManager autoload is present", dm != null)

	# WeatherFX is a global class_name, not an autoload -- resolvable directly, no tree lookup needed.
	ck.call("asset store plugins: WeatherFX.effects() lists at least 3 effects (rain/snow/fog)", WeatherFX.effects().size() >= 3)

	# ItemShapeBreakableItem is a plain class_name script (StaticBody2D), never an autoload --
	# instantiate one directly and confirm its take_hit() API exists, then free it immediately
	# (this is a bare scripted node with no texture set, not meant to live in the tree).
	var breakable := ItemShapeBreakableItem.new()
	ck.call("asset store plugins: ItemShapeBreakableItem instantiates and has take_hit()", breakable != null and breakable.has_method("take_hit"))
	if breakable != null:
		breakable.free()

	main.queue_free()
	await main.get_tree().process_frame
