extends RefCounted
## Every floor tile must cover its whole 72 x 36 lattice diamond: 1 tile = 1 square, no white void between tiles.
## Water shore pieces (water_role) are partial by design and are exempt.

const MIN_COVER := 0.98


static func coverage(id: String) -> float:
	var at := PlacedObjects.art_texture(id, Vector2.ZERO)
	var tl: Vector2 = at[1]
	var img: Image = (at[0] as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var hit := 0
	var tot := 0
	for y in range(-18, 18):
		for x in range(-36, 36):
			if absf(x + 0.5) / 36.0 + absf(y + 0.5) / 18.0 >= 0.96:
				continue
			tot += 1
			var px := x - int(tl.x)
			var py := y - int(tl.y)
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a > 0.5:
				hit += 1
	return float(hit) / float(maxi(tot, 1))


func run(ck: Callable, _root: Node) -> void:
	var n := 0
	var worst := 1.0
	var worst_id := ""
	for id in PlacedObjects.CATALOG.keys():
		if not PlacedObjects.is_floor_tile(id) or id.begins_with("water9_"):
			continue
		n += 1
		var c := coverage(id)
		if c < worst:
			worst = c
			worst_id = id
		ck.call("floor tile %s covers its diamond (%.1f%%)" % [id, c * 100.0], c >= MIN_COVER)
	ck.call("checked a real set of floor tiles (%d)" % n, n >= 70)
	ck.call("worst floor tile is %s at %.1f%%" % [worst_id, worst * 100.0], worst >= MIN_COVER)
