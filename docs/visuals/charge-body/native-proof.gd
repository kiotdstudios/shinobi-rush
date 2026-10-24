extends SceneTree

func _initialize() -> void:
	var file := FileAccess.open("res://docs/visuals/charge-body/manifest.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for character in data.characters:
		for direction in data.characters[character]:
			for path in data.characters[character][direction]:
				var texture := load(path) as Texture2D
				if texture == null or texture.get_size() != Vector2(128, 128):
					push_error("CHARGE_BODY_FAIL: " + path)
					quit(1)
					return
				count += 1
			var atlas := load("res://assets/characters/%s/charge_body/atlases/%s.png" % [character, direction]) as Texture2D
			if atlas == null or atlas.get_size() != Vector2(512, 512):
				push_error("CHARGE_BODY_ATLAS_FAIL")
				quit(1)
				return
	print("CHARGE_BODY_PASS: ", count, " imported frames and 16 atlases")
	quit(0)
