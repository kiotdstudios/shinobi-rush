extends RefCounted
## Data-only art delivery: test imports and full registered diamond coverage.
const BASE := "res://assets/environment/blightwood/brown_dirt_path/"
func run(ck: Callable, _root: Node) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"brown-dirt-path.art.json"))
	ck.call("brown dirt: retains the existing grass canvas and anchor",Vector2(manifest.canvas[0],manifest.canvas[1])==Vector2(112,112) and Vector2(manifest.anchor[0],manifest.anchor[1])==Vector2(56,84) and Vector2(manifest.logical_tile_size[0],manifest.logical_tile_size[1])==Vector2(72,36))
	ck.call("brown dirt: art-only pack is not falsely marked runtime bound",not manifest.production_bound)
	for entry: Dictionary in manifest.tiles:
		var texture := load(String(entry.path)) as Texture2D
		var label := "brown dirt mask %02d" % int(entry.mask)
		ck.call(label+" imports at native size",texture!=null and texture.get_size()==Vector2(112,112))
		if texture==null:continue
		var image := texture.get_image()
		if image.is_compressed():image.decompress()
		var opaque := true
		for y in range(-18,18):
			for x in range(-36,36):
				if absf(x+.5)/36.0+absf(y+.5)/18.0<1.0:
					opaque = opaque and image.get_pixel(x+56,y+84).a==1.0
		ck.call(label+" has 100 percent opaque diamond coverage",opaque)
	for role: String in manifest.nine_roles:
		var texture := load(BASE+"tiles/dirt9_"+role+".png") as Texture2D
		var mask := int(manifest.nine_roles[role])
		var canonical := load(BASE+"tiles/dirt16_%02d.png" % mask) as Texture2D
		ck.call("brown dirt nine-role alias "+role,texture!=null and canonical!=null and texture.get_image().get_data()==canonical.get_image().get_data())
