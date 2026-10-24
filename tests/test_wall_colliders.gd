extends RefCounted
## Every wall-kit piece's collider must sit under its art: the base contour of the picture is inside the collider
## (nobody walks into the visible wall) and the collider does not stick out in front of it (no invisible wall).

func run(ck: Callable, _root: Node) -> void:
	for id: String in PlacedObjects.CATALOG:
		var def: Dictionary = PlacedObjects.CATALOG[id]
		if def.kind != "wall" or def.col == Vector2.ZERO or def.get("fence", false):
			continue
		var img := PlacedObjects.wall_texture(id).get_image()
		var pts := PlacedObjects.wall_collider_points(def)
		var inside := 0
		var front := 0
		var total := 0
		for x in range(6, img.get_width() - 6, 6):
			var bottom := -1
			for y in range(img.get_height() - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.16:
					bottom = y
					break
			if bottom < 0:
				continue
			total += 1
			var g := Vector2(x, bottom) - (def.anchor as Vector2)
			if Geometry2D.is_point_in_polygon(g + Vector2(0, -5), pts):
				inside += 1
			if not Geometry2D.is_point_in_polygon(g + Vector2(0, 14), pts):
				front += 1
		ck.call("wall collider %s: the picture's base is inside the collider (%d/%d)" % [id, inside, total], total > 0 and float(inside) / total >= 0.8)
		ck.call("wall collider %s: no invisible wall in front of the picture (%d/%d)" % [id, front, total], total > 0 and float(front) / total >= 0.85)
