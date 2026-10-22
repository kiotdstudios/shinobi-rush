extends SceneTree

func _initialize() -> void:
	var root := "res://assets/characters/player/kunai_poc/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "kunai-light1.art.json"))
	for frame: Dictionary in data["frames"]:
		var texture := load(root + str(frame["body_frame"])) as Texture2D
		assert(texture != null and texture.get_size() == Vector2(128, 128))
	var weapon := load("res://assets/weapons/kunai/black_kunai.png") as Texture2D
	assert(weapon != null and weapon.get_size() == Vector2(64, 64))
	var image := weapon.get_image()
	assert(image.get_pixel(25, 31).a == 1.0 and image.get_pixel(17, 31).a == 0.0)
	print("PASS6 native128RGBA kunai body textures and64RGBA separate weapon imported")
	quit(0)
