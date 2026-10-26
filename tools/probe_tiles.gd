extends SceneTree

func _init() -> void:
	var rows := []
	for id in PlacedObjects.CATALOG.keys():
		if not PlacedObjects.is_floor_tile(id):
			continue
		var at: Array = PlacedObjects.art_texture(id, Vector2.ZERO)
		var tex: Texture2D = at[0]
		var tl: Vector2 = at[1]
		var img := tex.get_image()
		var hit := 0
		var tot := 0
		for y in range(-18, 18):
			for x in range(-36, 36):
				var nx: float = (abs(x + 0.5) / 36.0) + (abs(y + 0.5) / 18.0)
				if nx >= 0.96:
					continue
				tot += 1
				var px := x - int(tl.x)
				var py := y - int(tl.y)
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a > 0.5:
					hit += 1
		rows.append("%s|%dx%d|%d/%d|%.1f" % [id, img.get_width(), img.get_height(), hit, tot, 100.0 * hit / max(tot, 1)])
	rows.sort()
	for r in rows:
		print("TILE ", r)
	quit()
