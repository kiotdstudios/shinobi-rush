extends SceneTree
## Data-only asset import verification; never instantiates/registers a gameplay pickup.
func _initialize() -> void:
	var frames := load("res://assets/pickups/ryo_pouch/animations.tres") as SpriteFrames
	assert(frames != null)
	var expected := {"idle":16,"glow":12,"ember":22,"floor_glow":12,"collect":8}
	for key: String in expected:
		assert(frames.has_animation(key))
		assert(frames.get_frame_count(key)==expected[key])
		for i in frames.get_frame_count(key):
			var tex := frames.get_frame_texture(key,i)
			assert(tex != null)
			assert(tex.get_size()==(Vector2(128,128) if key in ["idle","collect"] else Vector2(96,96)))
	assert(not frames.get_animation_loop("collect"))
	var seconds := 0.0
	for i in 8:seconds += frames.get_frame_duration("collect",i)/frames.get_animation_speed("collect")
	assert(absf(seconds-0.4)<0.0001)
	var clear := frames.get_frame_texture("collect",7).get_image()
	assert(clear.get_used_rect().size==Vector2i.ZERO)
	var material := load("res://assets/pickups/ryo_pouch/additive.tres") as CanvasItemMaterial
	assert(material != null and material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD)
	print("RYO_ART_IMPORT: 5 animation tracks / 70 playback frames / 60 source textures / terminal clear / 0.4s collect / additive material: PASS")
	quit(0)
