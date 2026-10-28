extends RefCounted
func run(ck: Callable,root: Node) -> void:
	var data := TerrainJunctionArt.data()
	ck.call("junction art: exactly two missing pairs",data.pairs.size()==2)
	ck.call("junction art: all ten triples, six reusable patterns",data.junctions.size()==10 and data.patterns.size()==6)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave=false
	var obstacles := placed.obstacles().size()
	for group: Dictionary in data.pairs+data.junctions:
		var imported := true
		var lookup := true
		for tile: Dictionary in group.tiles:
			var texture := load(String(tile.path)) as Texture2D
			imported = imported and texture!=null and texture.get_size()==Vector2(72,36) and PlacedObjects.CATALOG.has(tile.id)
			var expected := String(tile.id)
			if group.has("id"):expected=expected.left(-1)+"a"
			var resolved := TerrainJunctionArt.tile_id(tile.corners)
			if group.has("id") and int(tile.mask) in [0,15]:
				# A pure material has several family aliases; lookup selects one canonical ID.
				lookup = lookup and PlacedObjects.ground_texture(resolved).get_image().get_data()==texture.get_image().get_data()
			else:
				lookup = lookup and resolved==expected
		var sample: String = group.tiles[0].id
		ck.call("junction art: imports "+sample,imported)
		ck.call("junction art: exact corner lookup "+sample,lookup)
		var category := PlacedObjects.type_of(sample)
		ck.call("junction art: category "+sample,arena.editor._filter_buttons.has(category))
		var pos := Vector2(720,900)
		var obj := placed.add(sample,pos)
		placed.move(obj,Vector2(792,900))
		ck.call("junction art: move and undo "+sample,placed.undo() and obj.pos==pos)
		ck.call("junction art: redo "+sample,placed.redo() and obj.pos==Vector2(792,900))
		placed.load_dict(placed.to_dict())
		obj=placed.ground_at(Vector2(792,900))
		ck.call("junction art: save reload "+sample,not obj.is_empty() and obj.id==sample)
		placed.remove(obj)
		ck.call("junction art: delete undo "+sample,placed.undo() and not placed.ground_at(Vector2(792,900)).is_empty())
		placed.remove(placed.ground_at(Vector2(792,900)))
		arena.editor.set_type_filter(category,false)
		ck.call("junction art: filter "+sample,not arena.editor._category_sections[category].visible)
		arena.editor.set_type_filter(category,true)
	ck.call("junction art: four distinct materials explicitly unsupported",TerrainJunctionArt.tile_id(["grass","ground","dirt","rock"])=="")
	ck.call("junction art: unknown material rejected",TerrainJunctionArt.tile_id(["water","ground","dirt","rock"])=="")
	ck.call("junction art: no new collision",placed.obstacles().size()==obstacles)
	main.queue_free()
	await root.get_tree().process_frame
