extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var old_map:=BlightwoodMap.enabled
	var old_shrine:=AncientShrineSection.enabled
	BlightwoodMap.enabled=false
	AncientShrineSection.enabled=false
	var main: Node=(load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree:=root.get_tree()
	for i in 4:await tree.process_frame
	var arena:=main.get_node("TrainingArena") as TrainingArena
	var placed:=arena.placed
	placed.autosave=false
	placed.clear_all(false)
	for enemy in tree.get_nodes_in_group("enemy"):enemy.queue_free()
	var origin:=Vector2(-225,180)
	for id: String in BlightwoodFoliage.IDS:
		var info:=PlacedObjects.def_of(id)
		var obj:=placed.add(id,origin,true)
		var plant:=obj.nodes[0] as BlightwoodFoliage
		plant.set_process(false)
		ck.call("foliage: transparent sprite and catalog "+id,plant!=null and not PlacedObjects.art_texture(id,origin).is_empty())
		var foot:=plant.position+plant.offset+(info.anchor as Vector2)+Vector2(0,float(info.lift))
		ck.call("foliage: correct pinned top/root and 66px vine lift "+id,foot.is_equal_approx(origin) and plant.get_child_count()==0)
		ck.call("foliage: native silhouette controls visible sway range "+id,float((plant.material as ShaderMaterial).get_shader_parameter("sway_length"))==float(info.sway_length) and float(info.sway_length)>0.0)
		var before:=plant.position
		plant.advance(.75)
		ck.call("foliage: wind phase advances without moving attachment "+id,plant.position==before and int((plant.material as ShaderMaterial).get_shader_parameter("phase_index"))==18)
		var sample: Vector2=origin-(info.anchor as Vector2)-Vector2(0,float(info.lift))+(info.pick as Vector2)
		ck.call("foliage: thin leaves are selectable "+id,PlacedObjects.art_pixel_hit(id,origin,sample) and placed.hit_test(sample).get("id","")==id)
		placed.move(obj,origin+Vector2(80,0),true)
		ck.call("foliage: move preserves root alignment "+id,(plant.position+plant.offset+(info.anchor as Vector2)+Vector2(0,float(info.lift))).is_equal_approx(origin+Vector2(80,0)))
		placed.undo()
		ck.call("foliage: undo restores placement "+id,obj.pos==origin)
		placed.set_type_visible("Blightwood foliage",false)
		ck.call("foliage: world layer eye hides sprite "+id,not plant.visible)
		placed.set_type_visible("Blightwood foliage",true)
		placed.remove(obj,true)
		placed.redo() # empty redo after deletion must stay safe
		for i in 2:await tree.process_frame
	ck.call("foliage: own object category and layer",AssetBrowser.categories_of("objects").has("Blightwood foliage") and WorldEditor.layer_names().has("Blightwood foliage"))
	for id: String in BlightwoodFoliage.IDS:placed.add(id,origin,true)
	placed._changed(false)
	ck.call("foliage: decorations never block navigation",placed.obstacles().is_empty() and placed.can_place("blight_fern_01",(arena.get_node("Player") as Node2D).position))
	var text:=placed.to_json_string()
	placed.load_dict(JSON.parse_string(text))
	ck.call("foliage: all six survive exact save/reload",placed.objects.size()==6 and placed.to_json_string()==text)
	main.queue_free()
	for i in 4:await tree.process_frame
	BlightwoodMap.enabled=old_map
	AncientShrineSection.enabled=old_shrine
