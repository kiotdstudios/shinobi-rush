extends SceneTree

func _initialize() -> void:
	var root := "res://assets/pickups/chakra_gourd/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "chakra_gourd.art.json"))
	var count := 0
	for layer in manifest.layers:
		var info: Dictionary = manifest.layers[layer]
		var expected := Vector2(float(info.frame_size[0]), float(info.frame_size[1]))
		for path in info.frames:
			var texture := load(root + path) as Texture2D
			if texture == null or texture.get_size() != expected:
				push_error("CHAKRA_GOURD_FAIL: " + str(path))
				quit(1)
				return
			count += 1
	print("CHAKRA_GOURD_PASS: ", count, " imported transparent pickup frames")
	quit(0)
