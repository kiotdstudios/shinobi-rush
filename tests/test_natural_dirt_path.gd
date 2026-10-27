extends RefCounted
func run(ck: Callable, _root: Node) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NaturalDirtPath.DIR+"natural-path.json"))
	ck.call("natural dirt: presentation preserves collision and grass source",not data.collision_changes and not data.grass_regenerated)
	var all_opaque := true
	var curved := 0
	var dirt_cells := 0
	for entry: Dictionary in data.entries:
		var id := "ground9_center" if entry.terrain == "d" else "grass9_center"
		var pos := Vector2(entry.x,entry.y)
		var texture := NaturalDirtPath.texture_for(id,pos)
		if texture == null:
			all_opaque = false
			continue
		var image := texture.get_image()
		if image.is_compressed():image.decompress()
		for y in range(-18,18):
			for x in range(-36,36):
				if absf(x+.5)/36+absf(y+.5)/18<1:
					all_opaque = all_opaque and image.get_pixel(x+56,y+84).a==1.0
		if entry.dirt_pixels>0 and entry.dirt_pixels<entry.opaque_pixels:curved+=1
		if entry.terrain=="d":dirt_cells+=1
	ck.call("natural dirt: all authored dirt cells covered",dirt_cells==BlightwoodMap.terrain_cells().d.size())
	ck.call("natural dirt: every cut diamond fully opaque",all_opaque)
	ck.call("natural dirt: curves cross tile interiors",curved>100)
	ck.call("natural dirt: custom paint and other floor families win",NaturalDirtPath.texture_for("temple_floor_center",Vector2.ZERO)==null and NaturalDirtPath.texture_for("grass9_center",BlightwoodMap.spawn_point())==null)
	ck.call("natural dirt: custom positions retain original art",NaturalDirtPath.texture_for("ground9_center",Vector2(10000,10000))==null)
	var sprite := Sprite2D.new()
	NaturalDirtPath.apply(sprite,"ground9_center",BlightwoodMap.spawn_point())
	ck.call("natural dirt: sprite and editor use the same foot registration",sprite.texture!=null and not sprite.centered and sprite.offset==Vector2(-56,-84) and PlacedObjects.art_texture("ground9_center",BlightwoodMap.spawn_point())[1]==BlightwoodMap.spawn_point()-Vector2(56,84))
	sprite.free()
