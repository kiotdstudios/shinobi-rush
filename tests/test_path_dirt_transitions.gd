extends RefCounted
const BASE := "res://assets/environment/blightwood/path_dirt_transitions/"
func run(ck: Callable, root: Node) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"path-dirt.art.json"))
	ck.call("path dirt: 16 corner masks with 3 variations",data.tiles.size()==48 and data.variations==3)
	var coverage := true
	var unique := {}
	for entry: Dictionary in data.tiles:
		var texture := load(str(entry.path)) as Texture2D
		ck.call("path dirt: imported native "+str(entry.id),texture!=null and texture.get_size()==Vector2(72,36))
		if texture==null:
			coverage=false
			continue
		var image := texture.get_image()
		if image.is_compressed():image.decompress()
		for y in range(36):
			for x in range(72):
				if absf(x+.5-36)/36+absf(y+.5-18)/18<1:
					coverage=coverage and image.get_pixel(x,y).a==1
		if int(entry.mask) not in [0,15]:unique[hash(image.get_data())]=true
	ck.call("path dirt: every transition is a full opaque diamond",coverage)
	ck.call("path dirt: 42 distinct mixed boundary variations",unique.size()==42)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave=false
	ck.call("path dirt: own builder filter",arena.editor._filter_buttons.has("Path to dirt"))
	var obstacles := placed.obstacles().size()
	var tile := placed.add("path_dirt_12_b",Vector2(720,900),false)
	ck.call("path dirt: placed on floor without collision",not tile.is_empty() and placed.obstacles().size()==obstacles and (tile.nodes[0] as Sprite2D).get_parent().name=="Ground")
	placed.move(tile,Vector2(792,900),false)
	ck.call("path dirt: builder move retains native registration",(tile.nodes[0] as Sprite2D).position==Vector2(792,900) and (tile.nodes[0] as Sprite2D).texture.get_size()==Vector2(72,36))
	var save := placed.to_dict()
	placed.load_dict(save)
	var found := {}
	for obj: Dictionary in placed.objects:
		if obj.id=="path_dirt_12_b" and obj.pos==Vector2(792,900):found=obj
	ck.call("path dirt: save reload retains material and position",not found.is_empty())
	if not found.is_empty():
		placed.remove(found,false)
		ck.call("path dirt: builder delete",not placed.objects.has(found))
	arena.editor.set_type_filter("Path to dirt",false)
	ck.call("path dirt: filter hides its palette section",not arena.editor._category_sections["Path to dirt"].visible)
	main.queue_free()
	await root.get_tree().process_frame
