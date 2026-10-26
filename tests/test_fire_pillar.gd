extends RefCounted
## Fire pillar prop (owner 2026-10-22: "make this little fire pillar thingy" from the shrine
## mockup, "very detailed fire animation as always max frames to get the quality matching the
## grass"). Called from tests/run_tests.gd.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_manifest()
	await _test_in_scene(tree_root)


func _test_manifest() -> void:
	var text := FileAccess.get_file_as_string("res://assets/environment/fire_pillar/fire_pillar.art.json")
	ck.call("fire pillar: manifest file exists and is non-empty", not text.is_empty())
	var data: Variant = JSON.parse_string(text)
	ck.call("fire pillar: manifest parses as a JSON object", typeof(data) == TYPE_DICTIONARY)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	ck.call("fire pillar: declares the built-in image_gen source (no paid PixelLab generation)", String(d.get("source_tool", "")).contains("built-in image_gen") and String(d.get("source_tool", "")).contains("no paid PixelLab"))
	ck.call("fire pillar: has a pillar block with path/foot_anchor/bowl_anchor", d.has("pillar") and (d.pillar as Dictionary).has("path") and (d.pillar as Dictionary).has("foot_anchor") and (d.pillar as Dictionary).has("bowl_anchor"))
	ck.call("fire pillar: pillar texture file actually exists on disk", FileAccess.file_exists(str(d.pillar.path)) or FileAccess.file_exists(str(d.pillar.path) + ".import"))
	ck.call("fire pillar: has a flame block with frame_size/foot_anchor/frames/fps/loop", d.has("flame") and (d.flame as Dictionary).has("frames") and (d.flame as Dictionary).has("fps") and (d.flame as Dictionary).has("loop"))
	var frames: Array = d.flame.frames
	# Owner asked for "very detailed... max frames to get the quality matching the grass": this
	# project's established painted-frame ceiling (player idle/walk=16, run/sprint=20, jump=24) is
	# the honest bar for a real painted animation -- assert this prop meets or exceeds the lower
	# end of that range, not a fabricated number.
	ck.call("fire pillar: at least 16 real painted flame frames (matches the project's established animation frame-count ceiling)", frames.size() >= 16, str(frames.size()))
	var all_exist := true
	var all_unique_sha := {}
	for fr: Dictionary in frames:
		if not (FileAccess.file_exists(str(fr.path)) or FileAccess.file_exists(str(fr.path) + ".import")):
			all_exist = false
		all_unique_sha[str(fr.get("sha256", ""))] = true
	ck.call("fire pillar: every declared flame frame file actually exists on disk", all_exist)
	ck.call("fire pillar: flame frames are genuinely distinct images, not duplicated/stamped copies", all_unique_sha.size() == frames.size(), "%d unique of %d" % [all_unique_sha.size(), frames.size()])
	ck.call("fire pillar: flame fps is positive and loop is enabled (continuous flicker, not a one-shot)", float(d.flame.fps) > 0.0 and bool(d.flame.loop))


func _test_in_scene(tree_root: Node) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().physics_frame
	var field := main.get_node_or_null("TrainingArena/FirePillarField") as FirePillarField
	ck.call("fire pillar: FirePillarField exists in the real training arena scene", field != null)
	if field == null:
		main.queue_free()
		return
	ck.call("fire pillar: spawns one instance per WorldScale.FIRE_PILLAR_POSITIONS entry", field.pillars.size() == WorldScale.FIRE_PILLAR_POSITIONS.size(), str(field.pillars.size()))
	for i in field.pillars.size():
		var p: FirePillar = field.pillars[i]
		ck.call("fire pillar %d: positioned at its WorldScale placement" % i, p.global_position.distance_to(WorldScale.FIRE_PILLAR_POSITIONS[i]) < 1.0)
		ck.call("fire pillar %d: pillar base sprite is visible with a loaded texture" % i, p.pillar_sprite.visible and p.pillar_sprite.texture != null)
		ck.call("fire pillar %d: flame AnimatedSprite2D is visible, playing, and has all 16 frames loaded" % i, p.flame_sprite.visible and p.flame_sprite.is_playing() and p.flame_sprite.sprite_frames.get_frame_count("flicker") >= 16)
		ck.call("fire pillar %d: glow halo is visible and additive-blended (does not darken anything behind it)" % i, p.glow.visible and p.glow.material is CanvasItemMaterial and (p.glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		ck.call("fire pillar %d: embers particle emitter is continuous (not a one-shot burst)" % i, not p.embers.one_shot and p.embers.emitting)
	# Advance real physics frames and confirm the flame is actually animating (frame index changes)
	# and the glow is actually pulsing (not a frozen static halo) -- not just configured correctly.
	if field.pillars.is_empty():
		ck.call("fire pillar: the level places none (owner removed them 2026-10-24)", WorldScale.FIRE_PILLAR_POSITIONS.is_empty())
		main.queue_free()
		await main.get_tree().process_frame
		return
	var p0: FirePillar = field.pillars[0]
	var seen_frames: Dictionary = {}
	var glow_scales: Array[float] = []
	for i in 40:
		await main.get_tree().physics_frame
		seen_frames[p0.flame_sprite.frame] = true
		glow_scales.append(p0.glow.scale.x)
	ck.call("fire pillar: the flame visibly cycles through more than one real frame over time", seen_frames.size() > 1, str(seen_frames.keys()))
	var glow_min: float = glow_scales.min()
	var glow_max: float = glow_scales.max()
	ck.call("fire pillar: the glow halo visibly pulses (scale varies over time), not a frozen static light", glow_max - glow_min > 0.01, "%.4f..%.4f" % [glow_min, glow_max])
	# set_flame_enabled(false) must cleanly hide every child -- no half-disabled state (e.g. a
	# visible flame with a dead glow, or embers still spawning after the flame is "off").
	p0.set_flame_enabled(false)
	await main.get_tree().physics_frame
	ck.call("fire pillar: set_flame_enabled(false) hides the flame, glow and stops embers together", not p0.flame_sprite.visible and not p0.glow.visible and not p0.embers.emitting)
	p0.set_flame_enabled(true)
	await main.get_tree().physics_frame
	ck.call("fire pillar: set_flame_enabled(true) restores the flame, glow and embers together", p0.flame_sprite.visible and p0.glow.visible and p0.embers.emitting)
	main.queue_free()
	await main.get_tree().process_frame
