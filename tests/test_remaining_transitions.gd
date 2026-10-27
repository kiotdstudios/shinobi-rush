extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood/terrain_transitions/transitions.art.json"))
	ck.call("transitions: seven justified flat families",manifest.families.size()==7)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave=false
	var obstacles := placed.obstacles().size()
	for family: Dictionary in manifest.families:
		var masks := {}
		var imported := true
		for tile: Dictionary in family.tiles:
			masks[int(tile.mask)]=true
			var tex := load(String(tile.path)) as Texture2D
			imported = imported and tex!=null and tex.get_size()==Vector2(72,36) and PlacedObjects.CATALOG.has(tile.id)
		ck.call("transitions: all16 masks and44 native imports "+String(family.id),masks.size()==16 and family.tiles.size()==44 and imported)
		ck.call("transitions: builder category "+String(family.id),arena.editor._filter_buttons.has(family.label))
		var id := String(family.id)+"_06_b"
		var pos := Vector2(720,900)
		var obj := placed.add(id,pos)
		ck.call("transitions: place floor "+id,not obj.is_empty() and (obj.nodes[0] as Node).get_parent().name=="Ground")
		ck.call("transitions: undo place "+id,placed.undo() and placed.floor_tiles_in_cell(pos).is_empty())
		ck.call("transitions: redo place "+id,placed.redo() and not placed.floor_tiles_in_cell(pos).is_empty())
		obj=placed.ground_at(pos)
		placed.move(obj,Vector2(792,900))
		ck.call("transitions: move "+id,obj.pos==Vector2(792,900))
		ck.call("transitions: undo move "+id,placed.undo() and obj.pos==pos)
		ck.call("transitions: redo move "+id,placed.redo() and obj.pos==Vector2(792,900))
		var saved := placed.to_dict()
		placed.load_dict(saved)
		obj=placed.ground_at(Vector2(792,900))
		ck.call("transitions: reload "+id,not obj.is_empty() and obj.id==id)
		placed.remove(obj)
		ck.call("transitions: delete and undo "+id,placed.ground_at(Vector2(792,900)).is_empty() and placed.undo() and not placed.ground_at(Vector2(792,900)).is_empty())
		placed.remove(placed.ground_at(Vector2(792,900)))
		arena.editor.set_type_filter(family.label,false)
		ck.call("transitions: filter "+id,not arena.editor._category_sections[family.label].visible)
		arena.editor.set_type_filter(family.label,true)
	var bank := placed.add("shore_brown_06",Vector2(720,900),false)
	var water := bank.nodes[0] as BlightwoodWater
	ck.call("brown banks: separate land and reused animated water mask",water.bank.texture.resource_path.contains("brown_shorelines") and water.surface.texture.resource_path.ends_with("dirt_06.png") and water.surface.material!=null)
	ck.call("brown banks: own filter",arena.editor._filter_buttons.has("Brown banks"))
	placed.remove(bank,false)
	ck.call("transitions: no new collision",placed.obstacles().size()==obstacles)
	main.queue_free()
	await root.get_tree().process_frame
