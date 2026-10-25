extends RefCounted

func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	var editor := arena.editor
	editor.set_open(true)
	ck.call("volcanic builder: own category checkbox", editor._filter_buttons.has("Volcanic trees"))
	var baseline := placed.obstacles().size()
	var ids := ["ashen_sentinel","ashen_windbent","ashen_elder"]
	for i in ids.size():
		var obj := placed.add(ids[i],Vector2(1100+i*120,900),false)
		var tree := obj.nodes[0] as AshenTree
		ck.call("volcanic builder: animated native anchored tree " + ids[i], tree.auto_advance and tree.is_processing() and tree.flakes.size()==24 and tree.sprite.position==Vector2(-160,-416) and tree.sprite.texture.get_size()==Vector2(320,448))
		ck.call("volcanic builder: trunk collider " + ids[i], obj.nodes[1] is StaticBody2D)
		ck.call("volcanic builder: art category " + ids[i], PlacedObjects.type_of(ids[i])=="Volcanic trees" and PlacedObjects.art_rect(ids[i],obj.pos).size.y>350)
	ck.call("volcanic builder: nav includes three trunks", placed.obstacles().size()==baseline+3)
	await root.get_tree().process_frame
	var obj := placed.objects[placed.objects.size()-1]
	var tree := obj.nodes[0] as AshenTree
	editor.set_open(false)  # the open builder freezes the world, so the animation runs once play resumes
	var clock := tree.local_clock
	await root.get_tree().process_frame
	ck.call("volcanic builder: runtime clock advances", tree.local_clock>clock)
	placed.move(obj,Vector2(1500,900),false)
	ck.call("volcanic builder: moving updates art and trunk", tree.position==Vector2(1500,900) and (obj.nodes[1] as Node2D).position==tree.position)
	ck.call("volcanic builder: moved root pickable", placed.hit_test(Vector2(1500,900)+Vector2(0,-120)).get("id", "")=="ashen_elder")
	editor.set_tool("place","ashen_elder")
	editor.set_type_filter("Volcanic trees",false)
	ck.call("volcanic builder: filter cancels painting without hiding world tree", editor.tool=="select" and tree.visible and not editor._category_sections["Volcanic trees"].visible)
	var saved := placed.to_dict()
	placed.load_dict(saved)
	var count := 0
	var removed: Array[Node] = []
	for item in placed.objects.duplicate():
		if PlacedObjects.def_of(item.id).kind=="ashen_tree":
			count+=1
			removed.append_array(item.nodes)
			placed.remove(item,false)
	ck.call("volcanic builder: save reload keeps all variants", count==3)
	await root.get_tree().process_frame
	var freed := true
	for node in removed:
		freed = freed and not is_instance_valid(node)
	ck.call("volcanic builder: deleting frees ash, tree and collider", freed and placed.obstacles().size()==baseline)
	main.queue_free()
	await root.get_tree().process_frame
