extends SceneTree

func _initialize() -> void:
	var root := "res://assets/environment/blightwood/ground_path/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "ground-nine.art.json"))
	for tile: Dictionary in manifest.tiles:
		var texture := load(tile.path) as Texture2D
		if texture == null or texture.get_size() != Vector2(72, 36):
			push_error("Ground tile failed to import: " + str(tile.path))
			quit(1)
			return
	var atlas := load(root + "ground-nine-atlas.png") as Texture2D
	if atlas == null or atlas.get_size() != Vector2(216, 108):
		quit(1)
		return
	print("BLIGHTWOOD GROUND: nine tiles and atlas load PASS")
	quit(0)
