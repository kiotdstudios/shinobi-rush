extends SceneTree
## Art-only render/import verification. No main scene or gameplay changes.
func _init() -> void:
	call_deferred("render_kit")

func render_kit() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("111b21")
	background.size = Vector2(1440, 1000)
	stage.add_child(background)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood_bridges/bridges.art.json"))
	var loaded := 0
	for rel: String in data["sha256"]:
		var texture := load("res://assets/environment/blightwood_bridges/" + rel) as Texture2D
		if texture == null:
			push_error("Bridge texture import failed: " + rel)
			quit(1)
			return
		loaded += 1
	var examples := ["short_wood_u", "medium_wood_u", "long_wood_u", "short_rope_u", "medium_damaged_u", "long_rope_v"]
	for i in examples.size():
		var origin := Vector2(28 + (i % 3) * 470, 80 + floori(i / 3.0) * 420)
		# Display on the game's actual water tile; this is an art stage, not a traversable map.
		for u in range(-1, 9):
			for v in range(-2, 4):
				var water := Sprite2D.new()
				water.texture = load("res://assets/environment/blightwood_water/tiles/water9_center.png")
				water.position = origin + Vector2(70 + (u-v)*36, 50 + (u+v)*18)
				water.modulate.a = 0.65
				stage.add_child(water)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/environment/blightwood_bridges/prefabs/" + examples[i] + ".png")
		sprite.centered = false
		sprite.position = origin
		stage.add_child(sprite)
		var caption := Label.new()
		caption.text = examples[i].replace("_", " ").to_upper()
		caption.position = origin + Vector2(0, 310)
		caption.add_theme_font_size_override("font_size", 19)
		stage.add_child(caption)
	var heading := Label.new()
	heading.text = "BLIGHTWOOD BRIDGE KIT | Godot native import/render | two diagonal axes"
	heading.position = Vector2(28, 18)
	heading.add_theme_font_size_override("font_size", 24)
	stage.add_child(heading)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://docs/visuals/blightwood-bridges/godot-render.png"
	var error := viewport.get_texture().get_image().save_png(out)
	print("BRIDGE_ART_IMPORT: %d textures; screenshot=%s; save_error=%d" % [loaded, out, error])
	quit(0 if error == OK else 1)
