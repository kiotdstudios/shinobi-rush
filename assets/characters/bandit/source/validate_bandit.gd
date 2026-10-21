extends SceneTree

func _initialize() -> void:
	var path := "res://assets/characters/bandit/bandit_128.art.json"
	var sprite_set := SpriteSet.parse(FileAccess.get_file_as_string(path), path)
	assert(sprite_set.is_valid(), str(sprite_set.errors))
	var count := 0
	for action: String in ["idle", "run", "sprint"]:
		var frames := sprite_set.get_frames(action)
		assert(frames != null)
		for dir: String in SpriteSet.DIRS8:
			assert(frames.has_animation(dir), action + "/" + dir)
			for i in range(frames.get_frame_count(dir)):
				var texture := frames.get_frame_texture(dir, i)
				assert(texture != null and texture.get_size() == Vector2(128, 128))
				count += 1
	assert(count == 160, str(count))
	assert(not SpriteLibrary.discover_paths().has(path))
	print("BANDIT_IMPORT_PASS: 160 textures / 24 clips; opt-in set excluded from player discovery")
	quit(0)
