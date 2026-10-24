extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	var count := placed.objects.size()
	var obstacles := placed.obstacles().size()
	var owned: Array[Dictionary] = []
	for k in 3:
		var family: String = ["grass","dirt","rock"][k]
		var category: String = ["Grass banks","Dirt banks","Rocky banks"][k]
		ck.call("shore: dedicated palette "+family,arena.editor._filter_buttons.has(category))
		for mask in 16:
			var id := "shore_%s_%02d" % [family,mask]
			var obj := placed.add(id,Vector2(1000+(mask%8)*72,450+k*180+(mask/8)*72),false)
			owned.append(obj)
			var water := obj.nodes[0] as BlightwoodWater
			water.auto_advance = false
			ck.call("shore: native separate layers "+id,water.bank!=null and water.bank.texture.get_size()==Vector2(72,36) and water.surface.texture.get_size()==Vector2(72,36) and water.get_parent().name=="Ground")
			ck.call("shore: correct catalog identity "+id,water.shore_family==family and water.shore_mask==mask and PlacedObjects.type_of(id)==category)
	ck.call("shore: all48 decorative cells stay nonblocking",placed.objects.size()==count+48 and placed.obstacles().size()==obstacles)
	var first := owned[8].nodes[0] as BlightwoodWater
	var origin := first.position
	first.clock=0
	first.advance(0.5)
	ck.call("shore: rooted land and moving current",first.position==origin and first.bank.position==Vector2.ZERO and float((first.surface.material as ShaderMaterial).get_shader_parameter("motion_time"))==0.5)
	ck.call("shore: reuses existing water atlas",(first.surface.material as ShaderMaterial).get_shader_parameter("current_atlas").resource_path==BlightwoodWater.DIR+"surface-atlas.png")
	placed.move(owned[8],Vector2(1300,850),false)
	ck.call("shore: moving keeps both layers registered",first.position==Vector2(1300,850) and first.surface.position==Vector2.ZERO and first.bank.position==Vector2.ZERO)
	placed.set_type_visible("Grass banks",false)
	ck.call("shore: independent family visibility",not first.visible and (owned[24].nodes[0] as CanvasItem).visible)
	placed.set_type_visible("Grass banks",true)
	var cell := Vector2(1584,936)
	ck.call("shore: floor brush accepts shoreline",placed.paint_cell("shore_grass_12",cell))
	ck.call("shore: brush replaces water instead of stacking",placed.paint_cell("water9_center",cell) and placed.ground_at(cell).id=="water9_center")
	placed.remove(placed.ground_at(cell),false)
	var snapshot := placed.to_dict()
	placed.load_dict(snapshot)
	await root.get_tree().process_frame
	var restored := 0
	for obj in placed.objects:
		if not str(obj.id).begins_with("shore_"):continue
		restored += 1
		var water := obj.nodes[0] as BlightwoodWater
		if water.bank==null or water.shore_family.is_empty():restored=-1000;break
	ck.call("shore: save/load restores all48 layers",restored==48)
	for obj in placed.objects.duplicate():
		if str(obj.id).begins_with("shore_"):placed.remove(obj,false)
	await root.get_tree().process_frame
	ck.call("shore: deletion frees land and current layers",placed.objects.size()==count and placed.obstacles().size()==obstacles and not is_instance_valid(first))
	main.queue_free()
	await root.get_tree().process_frame
