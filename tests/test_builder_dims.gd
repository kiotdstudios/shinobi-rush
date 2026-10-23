extends RefCounted
## Builder guides: dimension boxes bound only the visible art, everything is OFF by default, floor grid clip math.
var ck: Callable


func run(p_ck: Callable, _root: Node) -> void:
	ck = p_ck
	var bad: Array = []
	var smaller := 0
	for id: String in PlacedObjects.CATALOG.keys():
		var pos := Vector2(500, 500)
		var ar := PlacedObjects.art_rect(id, pos)
		var at := PlacedObjects.art_texture(id, pos)
		if ar.size.x <= 0.0 or ar.size.y <= 0.0:
			bad.append(id)
		var tex: Texture2D = at[0]
		if tex != null:
			var full := Rect2(at[1], tex.get_size())
			if not full.grow(0.5).encloses(ar):
				bad.append(id + "-outside")
			if ar.size.x < full.size.x or ar.size.y < full.size.y:
				smaller += 1
	ck.call("dims: every catalog object has a non-empty art box inside its texture", bad.is_empty(), str(bad))
	ck.call("dims: padding is trimmed on at least some assets (box tighter than the texture)", smaller > 0, str(smaller))
	var e := WorldEditor.new()
	ck.call("dims: floor grid default OFF", not e.show_grid)
	ck.call("dims: no object type shows dimensions by default", not e.dims_on("Trees") and not e.dims_on("Temple walls") and not e.dims_on("Grass"))
	var seg := WorldEditor._clip_line(Rect2(0, 0, 100, 100), 0.5, 10.0)
	ck.call("grid: clipped line stays inside the rect", seg.size() == 2 and Rect2(0, 0, 100, 100).grow(0.01).has_point(seg[0]) and Rect2(0, 0, 100, 100).grow(0.01).has_point(seg[1]))
	ck.call("grid: a line outside the rect clips to nothing", WorldEditor._clip_line(Rect2(0, 0, 100, 100), 0.5, 500.0).is_empty())
	e.free()
