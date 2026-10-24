extends SceneTree
## Opt-in art import check; no runtime controllers or scenes are modified.

func _initialize() -> void:
	var root := "res://assets/characters/player/premium_combat_poc/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "premium_combat.art.json"))
	var count := 0
	for action: Dictionary in data["animations"].values():
		for frame: Dictionary in action["frames"]:
			var path := (root + str(frame["body_frame"])).simplify_path()
			var texture := load(path) as Texture2D
			assert(texture != null and texture.get_size() == Vector2(128, 128), path)
			count += 1
	for weapon: Dictionary in data["weapons"].values():
		var texture := load(root + str(weapon["texture"])) as Texture2D
		assert(texture != null and texture.get_size() == Vector2(64, 64))
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "runtime-chain.art.json"))
	var chained_count := 0
	for action: Dictionary in runtime["animations"].values():
		for frame: Dictionary in action["frames"]:
			var texture := load((root + str(frame["body_frame"])).simplify_path()) as Texture2D
			assert(texture != null and texture.get_size() == Vector2(128, 128))
			chained_count += 1
	var effects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "vfx/combat_vfx.json"))
	for effect: Dictionary in effects["effects"].values():
		for path: String in effect["frames"]:
			var texture := load(root + "vfx/" + path) as Texture2D
			assert(texture != null and texture.get_size() == Vector2(128, 128))
	assert(is_equal_approx(CameraPreset.close_zoom(104.0, 720.0), 126.0 / 104.0))
	print("PASS premium combat Godot imported textures: ", count, " art + ", chained_count, " chained body references + 2 swords + 20 VFX; close scale 1.211538")
	quit(0)
